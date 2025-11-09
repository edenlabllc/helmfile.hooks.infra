#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
RELEASE_NAME="${2}"
LIMIT="${3:-180}"

# Note: The hook is only valid for static self-hosted runners (not created by HorizontalRunnerAutoscaler from 0)
GO_TEMPLATE='
  {{- range .items -}}
    {{- if not .status.updatedReplicas -}}0{{- else if gt .status.replicas .status.updatedReplicas -}}0{{- end -}}
    {{- if not .status.readyReplicas -}}0{{- else if ne .status.replicas .status.readyReplicas -}}0{{- end -}}
  {{- end -}}
'

COUNT=1
while true; do
  STATUS="$(kubectl --namespace "${NAMESPACE}" get runnerdeployment,runnerset --selector "app.kubernetes.io/instance=${RELEASE_NAME}" --output "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    kubectl --namespace "${NAMESPACE}" get runnerdeployment,runnerset --selector "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done
