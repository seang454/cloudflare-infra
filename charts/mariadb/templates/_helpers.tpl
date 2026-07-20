{{- define "mariadb.fullname" -}}
{{ .Release.Name }}-mariadb
{{- end }}

{{- define "mariadb.labels" -}}
app.kubernetes.io/name: mariadb
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "mariadb.selectorLabels" -}}
app.kubernetes.io/name: mariadb
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "mariadb.secretName" -}}
{{ .Values.auth.existingSecret | default (printf "%s-auth" (include "mariadb.fullname" .)) }}
{{- end }}
