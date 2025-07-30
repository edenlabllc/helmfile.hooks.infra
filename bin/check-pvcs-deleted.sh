#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
K8S_LABELS=("${@}")
LIMIT="120"

if [[ ! "${2}" =~ ^[0-9]+$ ]];then
    K8S_LABELS="${K8S_LABELS[@]:1}"
else
    LIMIT="${2}"
    K8S_LABELS="${K8S_LABELS[@]:2}"
fi

PVC_IDS=( "$(kubectl -n "${NAMESPACE}" get pvc -l "${K8S_LABELS/ /,}" -o yaml | yq '.items[].spec.volumeName')" )

for PVC_ID in ${PVC_IDS[*]}; do
  COUNT=1
  while (kubectl get pv "${PVC_ID}" &> /dev/null); do
    if (( COUNT > LIMIT )); then
      >&2 echo "Limit exceeded."
      exit 1
    fi

    echo "PV name: ${PVC_ID} in the process of being removed."
    sleep 1
    ((++COUNT))
  done
done
