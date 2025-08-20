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
Writable mountpoint where the controller will create dbFile during init
*/}}
{{- define "dataMountDir" -}}
/persistent
{{- end }}

{{/*
Read-only mountpoint for run container to read the ctrl plane trust bundle created during init
*/}}
{{- define "ziti-controller.ctrlPlaneCaDir" -}}
ctrl-plane-cas
{{- end }}

{{/*
Filename of the ctrl plane trust bundle
*/}}
{{- define "ziti-controller.ctrlPlaneCasFile" -}}
ctrl-plane-cas.crt
{{- end }}

{{- define "ziti-controller.console" -}}
    {{- if ne (len .Values.consoleAltIngress) 0 -}}
https://{{ include "ziti-controller.tplOrLiteral" (dict "value" .Values.consoleAltIngress.host "context" .) }}:{{ include "ziti-controller.tplOrLiteral" (dict "value" .Values.consoleAltIngress.port "context" .) }}/zac/
    {{- else if .Values.managementApi.service.enabled -}}
https://{{ include "ziti-controller.tplOrLiteral" (dict "value" .Values.managementApi.advertisedHost "context" .) }}:{{ include "ziti-controller.tplOrLiteral" (dict "value" .Values.managementApi.advertisedPort "context" .) }}/zac/
    {{- else -}}
https://{{ .Values.clientApi.advertisedHost }}:{{ .Values.clientApi.advertisedPort }}/zac/
    {{- end }}
{{- end }}

{{/*
help the alt-certificate template find the members of webBindingPki.altServerCerts
that are managed by cert-manager
*/}}
{{- define "ziti-controller.getCertManagerAltServerCerts" -}}
{{- $filteredCerts := list -}}
{{- range . -}}
  {{- if eq .mode "certManager" -}}
    {{- $filteredCerts = append $filteredCerts . -}}
  {{- end -}}
{{- end -}}
{{- dict "certManagerCerts" $filteredCerts | toJson -}}
{{- end -}}

{{/*
help the configmap template find the mount path of an alternative server
certificate by looking up the secret name in the list of additional volumes
*/}}
{{- define "ziti-controller.lookupVolumeMountPath" -}}
{{- $secretName := .secretName -}}
{{- $matchingVolumeMountPath := "" -}}
{{- range .additionalVolumes }}
  {{- if and (eq .volumeType "secret") (eq .secretName $secretName) }}
    {{- $matchingVolumeMountPath = .mountPath }}
  {{- end }}
{{- end }}
{{- if $matchingVolumeMountPath }}
  {{- $matchingVolumeMountPath }}
{{- else }}
  {{- fail (printf "No matching additionalVolume found for secretName: %s" $secretName) }}
{{- end }}
{{- end -}}

{{/*
render as an inline template if the value is a string containing a go template,
else return the literal value
*/}}
{{- define "ziti-controller.tplOrLiteral" -}}
{{- $value := .value -}}
{{- $context := .context -}}
{{- if typeIs "string" $value -}}
  {{- $trimmed := trim $value -}}
  {{- if and (hasPrefix "{{" $trimmed) (hasSuffix "}}" $trimmed) -}}
    {{- tpl $value $context -}}
  {{- else -}}
    {{- $value -}}
  {{- end -}}
{{- else -}}
  {{- $value -}}
{{- end -}}
{{- end -}}

{{/*
Get the SPIFFE ID for a controller
Usage: {{ include "ziti-controller.get-spiffe-id-uri" . }}
Returns: spiffe://{trustDomain}/controller/{nodeName}
*/}}
{{- define "ziti-controller.get-spiffe-uri" -}}
  {{- $trustDomain := required ".Values.trustDomain must be set" .Values.trustDomain -}}
  {{- $nodeName := required ".Values.nodeName must be set" .Values.nodeName -}}
  spiffe://{{ $trustDomain }}/controller/{{ $nodeName }}
{{- end -}}
