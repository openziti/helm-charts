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
Validate cluster mode.
Returns one of: "standalone", "cluster-init", "cluster-join".

Rules:
- standalone: .Values.cluster.mode is "standalone"
- cluster-join: .Values.cluster.nodeName is set AND .Values.cluster.trustDomain is set AND .Values.ctrlPlane.alternativeIssuer is set (non-empty)
- cluster-init: .Values.cluster.nodeName is set AND .Values.cluster.trustDomain is set AND .Values.ctrlPlane.alternativeIssuer is empty
*/}}
{{- define "ziti-controller.clusterMode" -}}
  {{- $mode := .Values.cluster.mode | trim | lower -}}
  {{- if not (or (eq $mode "standalone") (eq $mode "cluster-init") (eq $mode "cluster-join")) -}}
    {{- fail (printf "invalid cluster mode: %s; valid values are: standalone, cluster-init, cluster-join" $mode) -}}
  {{- end -}}

  {{- if eq $mode "standalone" -}}
standalone
  {{- else if eq $mode "cluster-init" -}}
    {{- if or (eq .Values.cluster.trustDomain "") (eq .Values.cluster.nodeName "") -}}
      {{- fail "cluster-init requires .Values.cluster.trustDomain and .Values.cluster.nodeName to be set" -}}
    {{- end -}}
cluster-init
  {{- else -}}
    {{- /* cluster-join */ -}}
    {{- if or (eq .Values.cluster.trustDomain "") (eq .Values.cluster.nodeName "") -}}
      {{- fail "cluster-join requires .Values.cluster.trustDomain and .Values.cluster.nodeName to be set" -}}
    {{- end -}}
    {{- if eq (len .Values.ctrlPlane.alternativeIssuer) 0 -}}
      {{- fail "cluster-join requires .Values.ctrlPlane.alternativeIssuer to be set to the first node's ctrl plane root issuer in same namespace" -}}
    {{- end -}}
    {{- if eq (len .Values.cluster.endpoint) 0 -}}
      {{- fail "cluster-join requires .Values.cluster.endpoint to be set to a reachable ctrl plane endpoint address of an existing node (example: ctrl1.ziti.example.com:443 or ziti-ctrl1-controller-ctrl:1280)" -}}
    {{- end -}}
cluster-join
  {{- end -}}
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
Usage: {{ include "ziti-controller.get-spiffe-uri" . }}
Returns: spiffe://{trustDomain}/controller/{nodeName}
*/}}
{{- define "ziti-controller.get-spiffe-uri" -}}
  {{- $trustDomain := required ".Values.cluster.trustDomain must be set" .Values.cluster.trustDomain -}}
  {{- $nodeName := required ".Values.cluster.nodeName must be set" .Values.cluster.nodeName -}}
  spiffe://{{ $trustDomain }}/controller/{{ $nodeName }}
{{- end -}}
