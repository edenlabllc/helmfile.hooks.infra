#!/usr/bin/env bash

set -e

if [[ "${SKIP_ELASTIC_POSTSYNC_HOOK}" == "true" ]]; then
  echo "Skipped."
  exit 0
fi

RELEASE_NAME="${1:-elastic}"
NAMESPACE="${2:-elastic}"
LIMIT="${3:-240}"

COUNT=1

while true; do
  STATUS=$(kubectl --namespace "${NAMESPACE}" get elasticsearch "${RELEASE_NAME}" --output yaml | yq '.status.phase')
  if [[ "${STATUS}" != "Ready" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    kubectl --namespace "${NAMESPACE}" get elasticsearch "${RELEASE_NAME}"
    break
  fi
done
