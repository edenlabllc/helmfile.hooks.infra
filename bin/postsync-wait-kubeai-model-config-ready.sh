#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
RELEASE_NAME="${2}"
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
  STATUS="$(kubectl --namespace "${NAMESPACE}" get model --selector "app.kubernetes.io/instance=${RELEASE_NAME}" --output "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    echo
    kubectl --namespace "${NAMESPACE}" get model --selector "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done
