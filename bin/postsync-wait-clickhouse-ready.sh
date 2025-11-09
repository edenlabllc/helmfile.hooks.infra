#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
RELEASE_NAME="${2}"
LIMIT="${3:-180}"

function check_cr() {
  local OUTPUT="${1}"

  if [[ "${OUTPUT}" != "true" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    echo
    kubectl --namespace "${NAMESPACE}" get clickhouseinstallation "${RELEASE_NAME}" --ignore-not-found
    exit 0
  fi
}

COUNT=1
while true; do
  check_cr "$(kubectl --namespace "${NAMESPACE}" get clickhouseinstallation "${RELEASE_NAME}" --ignore-not-found --output yaml | yq ".status.status == \"Completed\"")"
done
