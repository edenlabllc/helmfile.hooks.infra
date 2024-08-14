#!/usr/bin/env bash

set -e

if [[ "${SKIP_ELASTIC_POSTSYNC_HOOK}" == "true" ]]; then
  echo "Skipped."
  exit 0
fi

while [ -n "$1" ]; do
  case "$1" in
    --limit) shift; LIMIT="$1"; shift;;
    --) shift; break;;
    *) break;;
  esac
done

RELEASE_NAME="${1:-elastic}"
NAMESPACE="${2:-elastic}"

LIMIT="${LIMIT:-240}"
COUNT=1

while true; do
  STATUS=$(kubectl -n "${NAMESPACE}" get elasticsearch "${RELEASE_NAME}" -o yaml | yq '.status.phase')
  if [[ "${STATUS}" != "Ready" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >2& echo "Limit exceeded."
    exit 1
  else
    kubectl -n "${NAMESPACE}" get elastic | grep "${RELEASE_NAME}"
    break
  fi
done
