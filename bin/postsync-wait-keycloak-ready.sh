#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly STATUS_TYPE="${3:-Ready}"
readonly LIMIT="${5:-180}"

KEYCLOAK_RESOURCE="${4:-keycloak}"
[[ "${STATUS_TYPE}" == "Done" ]] && KEYCLOAK_RESOURCE="keycloakrealmimport"
readonly KEYCLOAK_RESOURCE

# for keycloak cluster
readonly GO_TEMPLATE='
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
  kubectl --namespace "${NAMESPACE}" get "${KEYCLOAK_RESOURCE}" --selector "app.kubernetes.io/instance=${RELEASE_NAME}" "${@}"
}

COUNT=1
while true; do
  STATUS="$(cmd --output "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "$(basename "${0}"): Wait timeout exceeded."
    exit 1
  else
    echo
    cmd
    break
  fi
done
