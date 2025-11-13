#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly LIMIT="${3:-240}"

COUNT=1

while true; do
  STATUS="$(kubectl --namespace "${NAMESPACE}" get elasticsearch "${RELEASE_NAME}" --output yaml | yq '.status.phase')"
  if [[ "${STATUS}" != "Ready" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "$(basename "${0}"): Wait timeout exceeded."
    exit 1
  else
    kubectl --namespace "${NAMESPACE}" get elasticsearch "${RELEASE_NAME}"
    break
  fi
done
