#!/usr/bin/env bash

set -e

RELEASE_NAME="${1:-clickhouse}"
NAMESPACE="${2:-clickhouse}"
ACTION="${3}"
LIMIT="${4:-180}"

function check_cr() {
  local OUTPUT="${1}"

  if [[ "${OUTPUT}" != "true" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    kubectl -n "${NAMESPACE}" get clickhouseinstallation "${RELEASE_NAME}" --ignore-not-found

    exit 0
  fi
}

COUNT=1
if [[ "${ACTION}" == "delete" ]]; then
  while true; do
     check_cr "$(kubectl -n "${NAMESPACE}" get clickhouseinstallation "${RELEASE_NAME}" --ignore-not-found -o yaml | yq "length == 0")"
  done
else
  while true; do
    check_cr "$(kubectl -n "${NAMESPACE}" get clickhouseinstallation "${RELEASE_NAME}" --ignore-not-found -o yaml | yq ".status.status == \"Completed\"")"
  done
fi
