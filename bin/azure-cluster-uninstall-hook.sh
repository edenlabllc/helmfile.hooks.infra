#!/usr/bin/env bash

set -e

CLUSTER_NAME="${1}"
NAMESPACE="${2}"
WAIT_DELETE_CLUSTER="${3:-false}"

kubectl --namespace "${NAMESPACE}" delete cluster "${CLUSTER_NAME}" "--wait=${WAIT_DELETE_CLUSTER}"
