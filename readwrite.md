# Using ReadWriteMany (RWX) with Nextcloud on Kubernetes

If you want to use `ReadWriteMany` (RWX) so you can scale Nextcloud to multiple replicas (e.g., `replicaCount: 2` or higher) for high availability, you need to change how the application and storage are architected. 

Here is what you should do to make RWX work successfully:

## 1. Change the Storage Backend (Optional but Recommended)
Longhorn is amazing for block storage (RWO), but its built-in NFS Share Manager for RWX isn't built for high-performance file sharing. If you plan to heavily use RWX across your cluster, consider setting up a dedicated file storage system like **TrueNAS (NFS)**, **CephFS**, or a managed NFS service (like AWS EFS). These handle thousands of small file operations much better.

## 2. Bypass the Initial `rsync` (The Real Fix)
Since you are already using **MinIO (S3) for user data**, the *only* thing being stored on that `ReadWriteMany` PVC are Nextcloud's core PHP application files. 

Instead of having the Nextcloud pod copy 400MB of PHP files to the PVC every time it boots, you can skip the PVC entirely for the app files. 
There are two ways to do this:
* **Use the Alpine/FPM Image:** You can bake the Nextcloud files directly into a custom Docker image, or mount them as an `emptyDir` memory volume.
* **Use an `initContainer`:** You can use a lightweight `initContainer` to extract the files faster, but the best practice for Kubernetes is to treat the app files as ephemeral (read-only) and rely purely on S3 for persistence.

## 3. Handle Updates and Cron Jobs Safely
When running multiple Nextcloud replicas:
* **Cron Jobs:** Your cron job (which runs `cron.php`) must be configured to ensure it doesn't collide with background tasks running on the main pods. (The Helm chart you are using already handles this pretty well).
* **Updates (`occ upgrade`):** You can only run database migrations from **one pod**. If two pods try to run `occ upgrade` at the same time during a version update, your database will corrupt. You would need to scale down to 1 replica during Nextcloud version upgrades.

## How to do it in your Helm Chart today:
If you want to try enabling it right now on Longhorn anyway, you would need to:
1. Increase the `startupProbe` timeout to **60 minutes** (to give Longhorn's slow NFS enough time to finish the first-boot `rsync`).
2. Set `persistence.accessMode: ReadWriteMany`
3. Set `replicaCount: 2`

**However, be warned:** Every time a pod restarts or updates, it will run that slow `rsync` check over the network, which will make your Nextcloud deployments very slow to start up. For a small cluster, running 1 replica on `ReadWriteOnce` (like we have it now) is generally much faster and more stable!
