{{/*
Expand the name of the chart.
*/}}
{{- define "zrok2.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "zrok2.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "zrok2.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zrok2.commonLabels" -}}
helm.sh/chart: {{ include "zrok2.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "zrok2.labelsController" -}}
{{ include "zrok2.commonLabels" . }}
{{ include "zrok2.selectorLabelsController" . }}
{{- end }}

{{- define "zrok2.labelsFrontend" -}}
{{ include "zrok2.commonLabels" . }}
{{ include "zrok2.selectorLabelsFrontend" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zrok2.selectorLabelsController" -}}
app.kubernetes.io/name: {{ include "zrok2.name" . }}-controller
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "zrok2.selectorLabelsFrontend" -}}
app.kubernetes.io/name: {{ include "zrok2.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "zrok2.serviceAccountName" -}}
{{- default (include "zrok2.fullname" .) .Values.serviceAccount.name }}
{{- end }}

{{/*
Determine the store type and path based on postgresql configuration
*/}}
{{- define "zrok2.storeType" -}}
{{- if .Values.postgresql.host -}}
postgres
{{- else -}}
sqlite3
{{- end }}
{{- end }}

{{- define "zrok2.storePath" -}}
{{- if .Values.postgresql.host -}}
{{- $passwordSegment := "" -}}
{{- if .Values.postgresql.password }}
{{- $passwordSegment = printf " password=%s" .Values.postgresql.password -}}
{{- else if .Values.postgresql.existingSecret }}
{{- $passwordSegment = " password=${ZROK2_DB_PASSWORD}" -}}
{{- end }}
host={{ .Values.postgresql.host }} port={{ .Values.postgresql.port }} user={{ .Values.postgresql.username }} dbname={{ .Values.postgresql.database }}{{ $passwordSegment }} sslmode=disable
{{- else -}}
{{ .Values.controller.persistence.mount_dir }}/zrok2.sqlite3
{{- end }}
{{- end }}
