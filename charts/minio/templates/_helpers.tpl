{{- define "minio.fullname" -}}
{{ .Release.Name }}-minio
{{- end }}

{{- define "minio.labels" -}}
app.kubernetes.io/name: minio
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "minio.selectorLabels" -}}
app.kubernetes.io/name: minio
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "minio.secretName" -}}
{{ .Values.existingSecret | default (printf "%s-auth" (include "minio.fullname" .)) }}
{{- end }}
