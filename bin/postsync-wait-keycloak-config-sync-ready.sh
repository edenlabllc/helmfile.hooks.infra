#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly LIMIT="${3:-300}"

readonly RESOURCES="keycloakrealms.config.idp.edenlab.io,keycloakauthflows.config.idp.edenlab.io,keycloakcomponents.config.idp.edenlab.io,keycloakclients.config.idp.edenlab.io,keycloakscopemappings.config.idp.edenlab.io,keycloakusers.config.idp.edenlab.io"

readonly GO_TEMPLATE='
  {{- range .items }}
    {{- if not .status }}0{{- end }}
    {{- if ne .status.phase "Completed" }}0{{- end }}
  {{- end -}}
'

COUNT=1
echo "Starting Keycloak CR status check in namespace: ${NAMESPACE}"

while true; do
  STATUS="$(kubectl --namespace "${NAMESPACE}" get "${RESOURCES}" --selector "app.kubernetes.io/instance=${RELEASE_NAME}" --output "go-template=${GO_TEMPLATE}" 2>/dev/null)"

  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "$(basename "${0}"): Wait timeout exceeded."
    exit 1
  else
    echo
    kubectl --namespace "${NAMESPACE}" get "${RESOURCES}" --selector "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done

echo "SUCCESS: Keycloak CR status check completed successfully!"
