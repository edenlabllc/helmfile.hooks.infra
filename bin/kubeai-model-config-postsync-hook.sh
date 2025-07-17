#!/usr/bin/env bash

set -e

RELEASE_NAME="${1}"
NAMESPACE="${2:-kubeai}"
LIMIT="${3:-10800}" # 3 hours (max time to load an AI model)

GO_TEMPLATE='
  {{- range .items }}
    {{- if not .status }}0{{- end }}
    {{- with .status }}
      {{- if not .replicas }}0{{- end }}
      {{- with .replicas }}
        {{- if gt .all .ready }}0{{- end }}
      {{- end }}
    {{- end }}
  {{- end -}}
'

COUNT=1
while true; do
  STATUS="$(kubectl -n "${NAMESPACE}" get model -l "app.kubernetes.io/instance=${RELEASE_NAME}" -o "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >2& echo "Limit exceeded."
    exit 1
  else
    echo
    kubectl -n "${NAMESPACE}" get model -l "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done
