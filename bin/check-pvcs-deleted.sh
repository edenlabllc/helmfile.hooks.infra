#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
LIMIT="${2:-120}"
K8S_LABELS=("${@}")
K8S_LABELS="${K8S_LABELS[@]:2}"

PVC_IDS=( "$(kubectl -n "${NAMESPACE}" get pvc -l "${K8S_LABELS/ /,}" -o yaml | yq '.items[].spec.volumeName')" )

for PVC_ID in ${PVC_IDS[*]}; do
  COUNT=1
  while (kubectl get pv "${PVC_ID}" &> /dev/null); do
    if (( COUNT > LIMIT )); then
      >2& echo "Limit exceeded."
      exit 1
    fi

    echo "PV name: ${PVC_ID} in the process of being removed."
    sleep 1
    ((++COUNT))
  done
done
