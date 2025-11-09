#!/usr/bin/env bash

set -e

CURRENT_ENVIRONMENT="${1}"
EXPECTED_ENVIRONMENT="${2}"
NAMESPACE="${3}"
RESOURCE_TYPE="${4}"
RESOURCE_NAME="${5}"
# get rest of arguments
ANNOTATIONS=("${@}")
ANNOTATIONS="${ANNOTATIONS[@]:5}"

if [[ "${CURRENT_ENVIRONMENT}" != "${EXPECTED_ENVIRONMENT}" ]]; then
  echo "Environment ${CURRENT_ENVIRONMENT} skipped when annotating, expected: ${EXPECTED_ENVIRONMENT}"
  exit 0
fi

if [[ "${RESOURCE_TYPE}" == "pod" ]]; then
  echo "Annotating all pods with prefix ${RESOURCE_NAME} in namespace ${NAMESPACE}"
  PODS="$(kubectl --namespace "${NAMESPACE}" get pod --output='yaml' | yq --unwrapScalar '.items[].metadata.name | select(test("'"^${RESOURCE_NAME}"'"))')"
  if [[ -z "${PODS}" ]]; then
    echo "No pods found with prefix ${RESOURCE_NAME}"
    exit 0
  fi
  for POD in "${PODS}"; do
    kubectl --namespace "${NAMESPACE}" annotate --overwrite pod "${POD}" ${ANNOTATIONS}
  done
else
  kubectl --namespace "${NAMESPACE}" annotate --overwrite "${RESOURCE_TYPE}" "${RESOURCE_NAME}" ${ANNOTATIONS}
fi
