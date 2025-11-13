#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly CURRENT_ENVIRONMENT="${2}"
readonly EXPECTED_ENVIRONMENT="${3}"
readonly RESOURCE_TYPE="${4}"
readonly RESOURCE_NAME_OR_PREFIX="${5}"
# get rest of arguments
LABELS=("${@}")
LABELS="${LABELS[@]:5}"

if [[ "${CURRENT_ENVIRONMENT}" != "${EXPECTED_ENVIRONMENT}" ]]; then
  echo "Environment ${CURRENT_ENVIRONMENT} skipped when labeling, expected: ${EXPECTED_ENVIRONMENT}"
  exit 0
fi

if [[ "${RESOURCE_TYPE}" == "pod" ]]; then
  echo "Annotating all pods with prefix ${RESOURCE_NAME_OR_PREFIX}- in namespace ${NAMESPACE}"

  PODS="$(
    kubectl --namespace "${NAMESPACE}" get pod --output yaml \
      | yq --unwrapScalar '
          .items[]
          | select(.metadata.name | startswith("'"${RESOURCE_NAME_OR_PREFIX}"'-"))
          | .metadata.name
        '
  )"

  if [[ -z "${PODS}" ]]; then
    echo "No pods found with prefix ${RESOURCE_NAME_OR_PREFIX}-"
    exit 0
  fi

  for POD in ${PODS}; do
    kubectl --namespace "${NAMESPACE}" label --overwrite pod "${POD}" ${LABELS}
  done
else
  kubectl --namespace "${NAMESPACE}" label --overwrite "${RESOURCE_TYPE}" "${RESOURCE_NAME_OR_PREFIX}" ${LABELS}
fi
