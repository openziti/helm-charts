{{/*
Expand the name of the chart.
*/}}

{{- define "ziti-router.name" -}}
    {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.  We truncate at 63 chars because some
Kubernetes name fields are limited to this (by the DNS naming spec).  If release
name contains chart name it will be used as a full name.
*/}}
{{- define "ziti-router.fullname" -}}
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
{{- define "ziti-router.chart" -}}
    {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ziti-router.labels" -}}
helm.sh/chart: {{ include "ziti-router.chart" . }}
{{ include "ziti-router.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ziti-router.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ziti-router.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ziti-router.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ziti-router.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
help the alt-certificate template find its DNS SAN by looking up the advertised
host of an additional listener
*/}}
{{- define "ziti-router.lookupAltServerCertHost" -}}
{{- $listenerName := .additionalListenerName -}}
{{- $additionalListeners:= .additionalListeners -}}
{{- $matchedListenerHost := "" -}}
{{- range $additionalListeners }}
  {{- if eq .name $listenerName }}
    {{- $matchedListenerHost = .advertisedHost }}
  {{- end }}
{{- end }}
{{- if $matchedListenerHost }}
  {{- $matchedListenerHost }}
{{- else }}
  {{- fail "No matched listener host found" }}
{{- end }}
{{- end }}

{{/*
help the alt-certificate template find the members of identity.altServerCerts
that are managed by cert-manager
*/}}
{{- define "ziti-router.getCertManagerAltServerCerts" -}}
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
{{- define "ziti-router.lookupVolumeMountPath" -}}
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
{{- define "ziti-router.tplOrLiteral" -}}
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