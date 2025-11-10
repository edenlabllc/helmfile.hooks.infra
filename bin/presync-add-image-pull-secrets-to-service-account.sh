#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
SA_NAME="${2}"
IPS_NAME="${3}"
ENABLE_HOOK="${4:-true}"
ENSURE_SA_CREATED="${5:-false}"

if [[ "${ENABLE_HOOK}" != "true" ]]; then
  echo "Skipped."
  exit 0
fi

if [[ "${ENSURE_SA_CREATED}" == "true" ]]; then
  echo "Ensuring service account \"${SA_NAME}\" created..."
  if ! (kubectl --namespace "${NAMESPACE}" get serviceaccount "${SA_NAME}" &> /dev/null); then
    # the same service account might have just been created by the hook of another PG (a race condition)
    # in this case, suppress the error using "true"
    kubectl --namespace "${NAMESPACE}" create serviceaccount "${SA_NAME}" || true
  fi
fi

kubectl --namespace "${NAMESPACE}" patch serviceaccount "${SA_NAME}" --type='merge' \
  -p '{"imagePullSecrets": [{"name": "'"${IPS_NAME}"'"}]}' \
  || exit 1
