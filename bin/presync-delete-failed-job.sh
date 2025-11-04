#!/usr/bin/env bash

set -e

JOB_NAME="${1}"
NAMESPACE="${2}"

if (kubectl --namespace "${NAMESPACE}" get job | grep "${JOB_NAME}"); then #todo remove grep
  JOB_ID=$(kubectl --namespace "${NAMESPACE}" get job | grep "${JOB_NAME}" | awk '{print $1}') #todo remove grep & awk
  FAILED_COUNT=$(kubectl --namespace "${NAMESPACE}" get job "${JOB_ID}" --output json | yq --unwrapScalar '.status.failed')
  if (( "${FAILED_COUNT}" > 0 )); then
    kubectl --namespace "${NAMESPACE}" delete job "${JOB_ID}"
  fi
fi
