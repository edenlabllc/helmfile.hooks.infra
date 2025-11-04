#!/usr/bin/env bash

set -e

JOB_NAME="${1}"
NAMESPACE="${2}"

if (kubectl get job --namespace "${NAMESPACE}" | grep "${JOB_NAME}"); then #todo remove grep
  JOB_ID=$(kubectl get job --namespace "${NAMESPACE}" | grep "${JOB_NAME}" | awk '{print $1}') #todo remove grep & awk
  FAILED_COUNT=$(kubectl get job "${JOB_ID}" --namespace "${NAMESPACE}" --output json | yq '.status.failed' --unwrapScalar)
  if (( "${FAILED_COUNT}" > 0 )); then
    kubectl delete job "${JOB_ID}" --namespace "${NAMESPACE}"
  fi
fi
