#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly JOB_PREFIX="${2}"

# Get all job names matching prefix
readonly JOB_NAMES="$(
  kubectl --namespace "${NAMESPACE}" get job --output yaml \
    | yq --unwrapScalar '
        .items[]
        | select(.metadata.name | startswith("'"${JOB_PREFIX}"'-"))
        | .metadata.name
      '
)"

if [[ -z "${JOB_NAMES}" ]]; then
  echo "No jobs with prefix \"${JOB_PREFIX}-\" found in namespace ${NAMESPACE}. Skipped."
  exit 0
fi

for JOB_NAME in ${JOB_NAMES}; do
  FAILED_COUNT="$(
    kubectl --namespace "${NAMESPACE}" get job "${JOB_NAME}" --output yaml \
      | yq --unwrapScalar '.status.failed // 0'
  )"

  if (( FAILED_COUNT > 0 )); then
    echo "Deleting failed job: ${JOB_NAME} (failed=${FAILED_COUNT})"
    kubectl --namespace "${NAMESPACE}" delete job "${JOB_NAME}"
  else
    echo "Job ${JOB_NAME} is healthy. Skipped."
  fi
done
