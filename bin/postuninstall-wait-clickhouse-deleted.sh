#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly LIMIT="${3:-180}"

readonly GO_TEMPLATE='{{- range .items }}0{{- end -}}'

COUNT=1
readonly RESOURCES="clickhouseinstallation,clickhousekeeperinstallation"
while true; do
  STATUS="$(kubectl --namespace "${NAMESPACE}" get "${RESOURCES}" --selector "app.kubernetes.io/instance=${RELEASE_NAME}" --output "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep "${SLEEP}"
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
