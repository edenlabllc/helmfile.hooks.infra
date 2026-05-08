#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"

kubectl delete pods --selector clickhouse.altinity.com/chi="${RELEASE_NAME}" --namespace "${NAMESPACE}" --grace-period=10 --wait=false
