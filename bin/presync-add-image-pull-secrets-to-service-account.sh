#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly SA_NAME="${2}"
readonly IPS_NAME="${3}"
readonly ENABLE_HOOK="${4:-true}"
readonly ENSURE_SA_CREATED="${5:-false}"

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
