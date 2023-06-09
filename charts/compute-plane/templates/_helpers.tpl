{{- define "compute-plane.name" -}}
{{- default .Release.Name .Values.name | trunc 46 | trimSuffix "-" }}
{{- end }}

{{- define "compute-plane.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "main-namespace" -}}
{{- default .Release.Namespace .Values.namespace }}
{{- end }}

{{- define "runs-namespace" -}}
{{- default (include "main-namespace" .) .Values.runs.namespace }}
{{- end }}

{{/*
Common
*/}}
{{- define "compute-plane.labels" -}}
helm.sh/chart: {{ include "compute-plane.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "compute-plane.service-api-key.name" -}}
{{- printf "%s-service-api-key" (include "compute-plane.name" .) }}
{{- end }}

{{- define "compute-plane.service-jwt.name" -}}
{{- printf "%s-service-jwt" (include "compute-plane.name" .) }}
{{- end }}

{{- define "compute-plane.imagePullSecretsEnv" -}}
{{- if len .Values.imagePullSecrets }}
{{- $list := list }}
{{- range $v := .Values.imagePullSecrets }}
{{- $list = append $list $v.name }}
{{- end }}
- name: MCLOUD_IMAGE_PULL_SECRETS
  value: {{ join "," $list }}
{{- else }}
{{- end }}
{{- end }}

{{/*
Worker
*/}}
{{- define "worker.name" -}}
{{- printf "%s-worker" (include "compute-plane.name" .) }}
{{- end }}

{{- define "worker.labels" -}}
{{ include "compute-plane.labels" . }}
app.kubernetes.io/name: {{ include "worker.name" . }}
{{- end }}

{{- define "worker.selector-labels" -}}
app.kubernetes.io/name: {{ include "worker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "worker.service-account-name" -}}
{{- if .Values.worker.rbac.create }}
{{- include "worker.name" . }}
{{- else }}
{{- .Values.worker.rbac.serviceAccountName }}
{{- end }}
{{- end }}

{{- define "worker.service-account-annotations" -}}
{{- deepCopy .Values.annotations | mustMerge .Values.worker.rbac.serviceAccountAnnotations | toYaml }}
{{- end }}


{{/*
Runs
*/}}
{{- define "runs.name" -}}
{{- printf "%s-runs" (include "compute-plane.name" .) }}
{{- end }}

{{- define "runs.labels" -}}
{{- include "compute-plane.labels" . }}
app.kubernetes.io/name: {{ include "runs.name" . }}
{{- end }}

{{- define "runs.service-account-name" -}}
{{- if .Values.runs.rbac.create }}
{{- include "runs.name" . }}
{{- else }}
{{- .Values.runs.rbac.serviceAccountName }}
{{- end }}
{{- end }}

{{- define "runs.service-account-annotations" -}}
{{- deepCopy .Values.annotations | mustMerge .Values.runs.rbac.serviceAccountAnnotations | toYaml }}
{{- end }}

{{/*
Node Doctor
*/}}
{{- define "node-doctor.name" -}}
{{- printf "%s-node-doctor" (include "compute-plane.name" .) }}
{{- end }}

{{- define "node-doctor.labels" -}}
{{- include "compute-plane.labels" . }}
app.kubernetes.io/name: {{ include "node-doctor.name" . }}
{{- end }}

{{- define "node-doctor.selector-labels" -}}
app.kubernetes.io/name: {{ include "node-doctor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "node-doctor.service-account-name" -}}
{{- if .Values.nodeDoctor.rbac.create }}
{{- include "node-doctor.name" . }}
{{- else }}
{{- .Values.nodeDoctor.rbac.serviceAccountName }}
{{- end }}
{{- end }}

{{- define "node-doctor.service-account-annotations" -}}
{{- deepCopy .Values.annotations | mustMerge .Values.nodeDoctor.rbac.serviceAccountAnnotations | toYaml }}
{{- end }}

{{/*
JWT Refresh
*/}}
{{- define "jwt-refresh.name" -}}
{{- printf "%s-jwt-refresh" (include "compute-plane.name" .) }}
{{- end }}

{{- define "jwt-refresh.labels" -}}
{{- include "compute-plane.labels" . }}
app.kubernetes.io/name: {{ include "jwt-refresh.name" . }}
{{- end }}

{{- define "jwt-refresh.selector-labels" -}}
app.kubernetes.io/name: {{ include "jwt-refresh.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "jwt-refresh.service-account-name" -}}
{{- if .Values.jwtRefresh.rbac.create }}
{{- include "jwt-refresh.name" . }}
{{- else }}
{{- .Values.jwtRefresh.rbac.serviceAccountName }}
{{- end }}
{{- end }}

{{- define "jwt-refresh.service-account-annotations" -}}
{{- deepCopy .Values.annotations | mustMerge .Values.jwtRefresh.rbac.serviceAccountAnnotations | toYaml }}
{{- end }}
