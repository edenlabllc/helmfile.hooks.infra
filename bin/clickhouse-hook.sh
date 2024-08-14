#!/usr/bin/env bash

set -e

while [ -n "$1" ]; do
  case "$1" in
    --limit) shift; LIMIT="$1"; shift;;
    --) shift; break;;
    *) break;;
  esac
done

RELEASE_NAME="${1:-clickhouse}"
NAMESPACE="${2:-clickhouse}"
ACTION="${3}"

LIMIT="${LIMIT:-180}"
COUNT=1

function watcher() {
  if [[ "${STATUS}" != "${PHRASE}" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >2& echo "Limit exceeded."
    exit 1
  else
    kubectl -n "${NAMESPACE}" get clickHouseinstallation 2>&1
    exit 0
  fi
}

if [[ "${ACTION}" == "delete" ]]; then
  PHRASE="No resources found in ${NAMESPACE} namespace."
  while true; do
    STATUS=$(kubectl -n "${NAMESPACE}" get clickHouseinstallation 2>&1)
    watcher
  done
else
  PHRASE="Completed"
  while true; do
    STATUS=$(kubectl -n "${NAMESPACE}" get clickHouseinstallation | head -2 | grep "${RELEASE_NAME}" | awk '{print $4}')
    watcher
  done
fi
