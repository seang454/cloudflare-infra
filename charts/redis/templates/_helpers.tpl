{{- define "redis.fullname" -}}
{{ .Release.Name }}-redis
{{- end }}

{{- define "redis.labels" -}}
app.kubernetes.io/name: redis
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "redis.selectorLabels" -}}
app.kubernetes.io/name: redis
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "redis.secretName" -}}
{{ .Values.existingSecret | default (printf "%s-auth" (include "redis.fullname" .)) }}
{{- end }}
