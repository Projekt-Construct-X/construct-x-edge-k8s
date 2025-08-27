{{/*
Weather app name
*/}}
{{- define "weather.name" -}}
{{- printf "%s-weather" .Release.Name }}
{{- end }}

{{/*
Weather labels
*/}}
{{- define "weather.labels" -}}
app: {{ include "weather.name" . }}
{{- end }}