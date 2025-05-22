{{- /*
Define a name template for minimal5gc
*/ -}}
{{- define "minimal5gc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- /*
Define a fullname template for minimal5gc
*/ -}}
{{- define "minimal5gc.fullname" -}}
{{- printf "%s-%s" (include "minimal5gc.name" .) .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
