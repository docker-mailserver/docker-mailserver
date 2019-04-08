{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{define "dockermailserver.name"}}{{default "dockermailserver" .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{end}}

{{/*
Create a default fully qualified app name.

We truncate at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec).
*/}}
{{define "dockermailserver.fullname"}}
{{- $name := default "dockermailserver" .Values.nameOverride -}}
{{printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{end}}

{{/*
Provide a pre-defined claim or a claim based on the Release
*/}}
{{- define "dockermailserver.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else -}}
{{- template "dockermailserver.fullname" . }}
{{- end -}}
{{- end -}}

