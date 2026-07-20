# Cloud Storage Platform — Helm Chart

Production Kubernetes deployment of Nextcloud (drive/UI) backed by MariaDB
(metadata), Redis (locking/cache), and MinIO (S3-compatible primary object
storage).

```
cloud-storage-platform/
├── Chart.yaml               # umbrella chart (no logic of its own)
├── values.yaml               # global defaults, nested per-subchart
├── templates/                 # only shared NOTES.txt/_helpers.tpl -- no resources
├── charts/
│   ├── mariadb/                # metadata store subchart
│   ├── redis/                  # locking/cache subchart
│   ├── minio/                  # S3 object storage subchart
│   └── nextcloud/               # php-fpm + nginx subchart
└── environments/
    ├── dev-values.yaml
    ├── staging-values.yaml
    └── production-values.yaml
```

Each subchart is fully self-contained (own `Chart.yaml`, `values.yaml`,
`templates/`) and can be installed, versioned, or reused independently of
this umbrella chart. The umbrella chart's `values.yaml` just nests config
under each subchart's name (`mariadb:`, `redis:`, `minio:`, `nextcloud:`),
which Helm automatically merges into that subchart's own values at render
time -- this is the standard umbrella-chart pattern.

## Why no Bitnami charts

Broadcom deprecated Bitnami's free public chart/image catalog in 2025 — the
legacy free images no longer receive security patches, and most charts moved
behind a paid "Bitnami Secure Images" subscription. Since this is meant for
production, `charts/mariadb`, `charts/redis`, and `charts/minio` are
hand-written using the official upstream images (`mariadb:11`,
`redis:7-alpine`, `minio/minio`) directly — no third-party chart dependency
to break under you later, and each is small enough to fully own and audit.

## Architecture

```
                 ┌────────────┐
 Internet ─────► │  Ingress   │  (nginx-ingress + cert-manager TLS)
                 └─────┬──────┘
                       ▼
              ┌─────────────────┐
              │  nextcloud Pod  │  (N replicas, HPA-scaled)
              │ ┌─────┐ ┌──────┐│
              │ │nginx│─│php-fpm││   RWX PVC: /var/www/html (app code/config)
              │ └─────┘ └──────┘│
              └────┬───────┬────┘
                   ▼        ▼
            ┌──────────┐ ┌────────┐        ┌─────────────┐
            │ MariaDB  │ │ Redis  │        │    MinIO     │
            │(metadata)│ │(locks) │        │ (file bytes, │
            └──────────┘ └────────┘        │  S3 objects) │
                                            └─────────────┘
```

- **MariaDB** stores metadata only: filenames, folder tree, users, shares,
  permissions, versions.
- **Redis** provides distributed file locking and memcache — required once
  you run more than one Nextcloud replica, or two replicas can corrupt
  concurrent writes to the same file.
- **MinIO** is configured as Nextcloud's *primary* object storage
  (`OBJECTSTORE_S3_*` env vars) — actual file bytes are stored as S3 objects,
  not on local disk.
- **nginx + php-fpm** run as two containers in the same Pod, sharing an
  emptyDir-free **ReadWriteMany PVC** at `/var/www/html` so both scale
  together and every replica sees the same app code/config.

## Prerequisites

- A Kubernetes cluster with a StorageClass that supports **ReadWriteMany**
  (Longhorn RWX, NFS-backed class, CephFS, etc.) — required for
  `nextcloud.persistence.accessMode: ReadWriteMany` when running more than
  one replica.
- `nginx-ingress` controller and `cert-manager` installed, if using the
  built-in Ingress/TLS (or disable `nextcloud.ingress` and front it yourself).
- Helm 3.x.

## Deploy

```bash
# Development (single replica, no TLS/HPA, ReadWriteOnce storage)
helm install csp-dev . -f environments/dev-values.yaml \
  -n nextcloud-dev --create-namespace

# Staging
helm install csp-staging . -f environments/staging-values.yaml \
  -n nextcloud-staging --create-namespace

# Production — create your Secrets first (see below), then:
helm install csp . -f environments/production-values.yaml \
  -n nextcloud-prod --create-namespace
```

Upgrade the same way with `helm upgrade`.

## Production secrets

`environments/production-values.yaml` references `existingSecret` names
(`csp-mariadb-auth`, `csp-redis-auth`, `csp-minio-auth`,
`csp-nextcloud-admin`) instead of plaintext passwords. Create these
beforehand — ideally via **External Secrets Operator** pulling from your
existing HashiCorp Vault instance, matching the pattern already used
elsewhere on this platform. See the comment block at the top of
`production-values.yaml` for the exact `ExternalSecret` shape each one needs
(keys: `mariadb-root-password`/`mariadb-password`, `redis-password`,
`root-user`/`root-password`, `username`/`password`).

If you don't set `existingSecret`, the chart auto-generates a Secret from the
plaintext values in `values.yaml` — fine for `dev`/`staging`, **do not** do
this for production.

## Encrypting file storage at rest

Once pods are healthy:
```bash
kubectl exec -it deploy/csp-nextcloud -c php-fpm -n nextcloud-prod -- \
  php occ app:enable encryption
kubectl exec -it deploy/csp-nextcloud -c php-fpm -n nextcloud-prod -- \
  php occ encryption:enable
kubectl exec -it deploy/csp-nextcloud -c php-fpm -n nextcloud-prod -- \
  php occ encryption:select-encryption-type
```
Upload a file through the UI, then pull the corresponding object straight out
of the MinIO bucket to confirm it's ciphertext, not the original content.

## Scaling notes

- `nextcloud.autoscaling` drives an HPA on CPU. Because all replicas share
  the same RWX PVC and both Redis (locking) and MinIO (storage) are
  externalized, scaling replicas is safe.
- MariaDB here is single-instance. For true DB HA, either point
  `mariadb.enabled: false` and supply an external managed MySQL/MariaDB
  endpoint via `nextcloud.database`, or swap in a Galera/Percona XtraDB
  Cluster operator.
- MinIO here runs in standalone (single-node) mode for simplicity. For
  production durability at scale, either run MinIO in distributed mode
  (4+ nodes, erasure coding) or point Nextcloud's `objectStore` at a managed
  S3-compatible service instead.

## Known gotcha

Configuring object storage as **primary** storage on an *existing* Nextcloud
install makes previously-stored local files inaccessible — the objectstore
config must be present from first boot, which this chart guarantees since the
env vars are set before Nextcloud's entrypoint runs its first-time setup.
