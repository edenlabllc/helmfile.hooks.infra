#!/usr/bin/env bash

set -e

RELEASE_NAME="${1}"
NAMESPACE="${2:-kafka}"
LIMIT="${3:-180}"

# for kafkaconnector also check connector and tasks' states in .status.connectorStatus
# for kafkamirrormaker2 also check connectors' and tasks' states in .status.connectors
GO_TEMPLATE='
  {{- range .items }}
    {{- if not .status }}0{{- end }}
    {{- range .status.conditions }}
      {{- if ne .type "Ready" }}0{{- end }}
      {{- if ne .status "True" }}0{{- end }}
    {{- end }}
    {{- with .status.connectorStatus }}
      {{- if ne .connector.state "RUNNING" }}0{{- end }}
      {{- range .tasks }}
        {{- if ne .state "RUNNING" }}0{{- end }}
      {{- end }}
    {{- end }}
    {{- with .status.connectors }}
      {{- range . }}
        {{- if ne .connector.state "RUNNING" }}0{{- end }}
        {{- range .tasks }}
          {{- if ne .state "RUNNING" }}0{{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end -}}
'

COUNT=1
K8S_RESOURCES="kafkaconnect,kafkaconnector,kafkamirrormaker2,kafkatopic"
while true; do
  STATUS="$(kubectl -n "${NAMESPACE}" get "${K8S_RESOURCES}" -l "app.kubernetes.io/instance=${RELEASE_NAME}" --output "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    echo
    kubectl -n "${NAMESPACE}" get "${K8S_RESOURCES}" -l "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done
