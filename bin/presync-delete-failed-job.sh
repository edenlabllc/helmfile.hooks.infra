#!/usr/bin/env bash

set -e

JOB_NAME="${1}"
NAMESPACE="${2}"

if (kubectl get jobs -n "${NAMESPACE}" | grep "${JOB_NAME}"); then #todo remove grep
  JOB_ID=$(kubectl get jobs -n "${NAMESPACE}" | grep "${JOB_NAME}" | awk '{print $1}') #todo remove grep & awk
  FAILED_COUNT=$(kubectl get job "${JOB_ID}" -n "${NAMESPACE}" -o json | yq '.status.failed' -r)
  if (( "${FAILED_COUNT}" > 0 )); then
    kubectl delete job "${JOB_ID}" -n "${NAMESPACE}"
  fi
fi
