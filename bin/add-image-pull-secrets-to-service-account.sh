#!/usr/bin/env bash

set -e

ENABLE_HOOK="${1}"
ENSURE_SA_CREATED="${2}"
NAMESPACE="${3}"
SA_NAME="${4}"
IPS_NAME="${5}"

if [[ "${ENABLE_HOOK}" != "true" ]]; then
  echo "Skipped."
  exit
fi

if [[ "${ENSURE_SA_CREATED}" == "true" ]]; then
  echo "Ensuring service account \"${SA_NAME}\" created..."
  if ! (kubectl -n "${NAMESPACE}" get serviceaccount "${SA_NAME}" &> /dev/null); then
    # the same service account might have just been created by the hook of another PG (a race condition)
    # in this case, suppress the error using "true"
    kubectl -n "${NAMESPACE}" create serviceaccount "${SA_NAME}" || true
  fi
fi

kubectl -n "${NAMESPACE}" patch serviceaccount "${SA_NAME}" --type='merge' \
  -p '{"imagePullSecrets": [{"name": "'"${IPS_NAME}"'"}]}' \
  || exit 1
