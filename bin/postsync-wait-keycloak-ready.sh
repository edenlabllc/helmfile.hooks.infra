#!/usr/bin/env bash

set -e

RELEASE_NAME="${1}"
NAMESPACE="${2:-keycloak}"
STATUS_TYPE="${3:-Ready}"
KEYCLOAK_RESOURCE="${4:-keycloak}"
LIMIT="${5:-180}"

[[ "${STATUS_TYPE}" == "Done" ]] && KEYCLOAK_RESOURCE="keycloakrealmimport"

# for keycloak cluster
GO_TEMPLATE='
  {{- range .items }}
    {{- if not .status }}0{{- end }}
    {{- if not .status.conditions}}0{{- end }}
    {{- with .status.conditions }}
      {{- if ne (index . 0).status "True" }}0{{- end }}
      {{- if ne (index . 0).type "'"${STATUS_TYPE}"'" }}0{{- end }}
    {{- end }}
  {{- end -}}
'

function cmd() {
  kubectl -n "${NAMESPACE}" get "${KEYCLOAK_RESOURCE}" -l "app.kubernetes.io/instance=${RELEASE_NAME}" "${@}"
}

COUNT=1
while true; do
  STATUS="$(cmd -o "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    echo
    cmd
    break
  fi
done
