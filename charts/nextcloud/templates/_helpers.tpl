{{- define "nextcloud.fullname" -}}
{{ .Release.Name }}-nextcloud
{{- end }}

{{- define "nextcloud.labels" -}}
app.kubernetes.io/name: nextcloud
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "nextcloud.selectorLabels" -}}
app.kubernetes.io/name: nextcloud
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
These follow the exact same naming convention as the parent chart's
csp.mariadb.fullname / csp.redis.fullname / csp.minio.fullname helpers
(<release-name>-mariadb, etc.), since both charts are installed together
as part of the same Helm release.
*/}}
{{- define "nextcloud.mariadb.host" -}}
{{ .Release.Name }}-mariadb
{{- end }}

{{- define "nextcloud.redis.host" -}}
{{ .Release.Name }}-redis
{{- end }}

{{- define "nextcloud.minio.host" -}}
{{ .Release.Name }}-minio
{{- end }}

{{- define "nextcloud.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ .Values.serviceAccount.name | default (include "nextcloud.fullname" .) }}
{{- else -}}
{{ .Values.serviceAccount.name | default "default" }}
{{- end -}}
{{- end }}
