#!/usr/bin/env bash

set -e

RELEASE_NAME="${1:-actions-runner}"
NAMESPACE="${2:-actions-runner}"
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
  STATUS="$(kubectl -n "${NAMESPACE}" get runnerdeployment,runnerset -l "app.kubernetes.io/instance=${RELEASE_NAME}" -o "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    kubectl -n "${NAMESPACE}" get runnerdeployment,runnerset -l "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done
