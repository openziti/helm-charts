{{/*
Expand the name of the chart.
*/}}

{{- define "ziti-controller.name" -}}
    {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ziti-controller.fullname" -}}
    {{- if .Values.fullnameOverride }}
        {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
    {{- else }}
        {{- $name := default ( trimPrefix "ziti-" .Chart.Name ) .Values.nameOverride }}
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
{{- define "ziti-controller.chart" -}}
    {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ziti-controller.labels" -}}
helm.sh/chart: {{ include "ziti-controller.chart" . }}
{{ include "ziti-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ziti-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ziti-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ziti-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ziti-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* 
A directory included in the init and run containers' executable search path
*/}}
{{- define "execMountDir" -}}
/usr/local/bin  
{{- end }}

{{/* 
Read-only mountpoint where configFile and various read-only identity dirs are projected
*/}}
{{- define "configMountDir" -}}
/etc/ziti
{{- end }}

{{/* 
Writeable mountpoint where the controller will create dbFile during init
*/}}
{{- define "dataMountDir" -}}
/persistent
{{- end }}

{{/*
Filename of the ctrl plane trust bundle
*/}}
{{- define "ziti-controller.ctrlPlaneCasFile" -}}
ctrl-plane-cas.crt
{{- end }}