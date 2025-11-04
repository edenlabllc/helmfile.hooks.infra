#!/usr/bin/env bash

set -e

CURRENT_ENVIRONMENT="${1}"
EXPECTED_ENVIRONMENT="${2}"
K8S_NAMESPACE="${3}"
K8S_RESOURCE_TYPE="${4}"
K8S_RESOURCE_NAME="${5}"
# get rest of arguments
K8S_ANNOTATIONS=("${@}")
K8S_ANNOTATIONS="${K8S_ANNOTATIONS[@]:5}"

if [[ "${CURRENT_ENVIRONMENT}" != "${EXPECTED_ENVIRONMENT}" ]]; then
  echo "Environment ${CURRENT_ENVIRONMENT} skipped when annotating, expected: ${EXPECTED_ENVIRONMENT}"
  exit
fi

if [[ "${K8S_RESOURCE_TYPE}" == "pod" ]]; then
  echo "Annotating all pods with prefix ${K8S_RESOURCE_NAME} in namespace ${K8S_NAMESPACE}"
  PODS=$(kubectl --namespace "${K8S_NAMESPACE}" get pod --output='yaml' | yq --unwrapScalar '.items[].metadata.name | select(test("'"^${K8S_RESOURCE_NAME}"'"))')
  if [[ -z "${PODS}" ]]; then
    echo "No pods found with prefix ${K8S_RESOURCE_NAME}"
    exit 0
  fi
  for POD in "${PODS}"; do
    kubectl --namespace "${K8S_NAMESPACE}" annotate --overwrite pod "${POD}" ${K8S_ANNOTATIONS}
  done
else
  kubectl --namespace "${K8S_NAMESPACE}" annotate --overwrite "${K8S_RESOURCE_TYPE}" "${K8S_RESOURCE_NAME}" ${K8S_ANNOTATIONS}
fi
