#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly LIMIT="${3:-180}"
readonly KEEPER_ENABLED="${4:-false}"

function check_cr() {
  local OUTPUT="${1}"

  if [[ "${OUTPUT}" != "true" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "$(basename "${0}"): Wait timeout exceeded."
    exit 1
  else
    echo
    kubectl --namespace "${NAMESPACE}" get clickhouseinstallation "${RELEASE_NAME}" --ignore-not-found
    exit 0
  fi
}

COUNT=1
while true; do
  check_cr "$(kubectl --namespace "${NAMESPACE}" get clickhouseinstallation "${RELEASE_NAME}" --ignore-not-found --output yaml | yq "length == 0")"

  if [[ "${KEEPER_ENABLED}" == "true" ]]; then
    check_cr "$(kubectl --namespace "${NAMESPACE}" get clickhousekeeperinstallation "${RELEASE_NAME}" --ignore-not-found --output yaml | yq "length == 0")"
  fi
done
