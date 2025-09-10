#!/usr/bin/env bash

set -e

CURRENT_ENVIRONMENT="${1}"
EXPECTED_ENVIRONMENT="${2}"
K8S_NAMESPACE="${3}"
K8S_RESOURCE_TYPE="${4}"
K8S_RESOURCE_NAME="${5}"
# get rest of arguments
K8S_LABELS=("${@}")
K8S_LABELS="${K8S_LABELS[@]:5}"

if [[ "${CURRENT_ENVIRONMENT}" != "${EXPECTED_ENVIRONMENT}" ]]; then
  echo "Environment ${CURRENT_ENVIRONMENT} skipped when labeling, expected: ${EXPECTED_ENVIRONMENT}"
  exit
fi

if [[ "${K8S_RESOURCE_TYPE}" == "pod" ]]; then
  echo "Annotating all pods with prefix ${K8S_RESOURCE_NAME} in namespace ${K8S_NAMESPACE}"
  PODS=$(kubectl -n "${K8S_NAMESPACE}" get pods --no-headers -o custom-columns=":metadata.name" | grep "^${K8S_RESOURCE_NAME}")
  if [[ -z "${PODS}" ]]; then
    echo "No pods found with prefix ${K8S_RESOURCE_NAME}"
    exit 0
  fi
  for POD in "${PODS}"; do
    kubectl -n "${K8S_NAMESPACE}" label --overwrite pod "${POD}" ${K8S_LABELS}
  done
else
  kubectl -n "${K8S_NAMESPACE}" label --overwrite "${K8S_RESOURCE_TYPE}" "${K8S_RESOURCE_NAME}" ${K8S_LABELS}
fi
