{{/*
Expand the name of the umbrella chart.
*/}}
{{- define "csp.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for resources owned directly by the umbrella chart (there
currently are none -- mariadb/redis/minio/nextcloud each own their own
resources via their subcharts). Kept here in case top-level resources
(e.g. a shared NetworkPolicy) are added later.
*/}}
{{- define "csp.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: cloud-storage-platform
{{- end }}
