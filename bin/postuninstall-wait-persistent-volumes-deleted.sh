#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
PVC_SELECTORS="${2}"
LIMIT="${3:-120}"

if [[ -z "${PVC_SELECTORS}" ]]; then
    echo "No label selector provided. Skipped."
    exit 0
fi

mapfile -t PVC_IDS < <(kubectl --namespace "${NAMESPACE}" get persistentvolumeclaim --selector "${PVC_SELECTORS}" --output yaml | yq --unwrapScalar '.items[].spec.volumeName')

for PVC_ID in "${PVC_IDS[@]}"; do
  COUNT=1
  while (kubectl get persistentvolume "${PVC_ID}" &> /dev/null); do
    if (( COUNT > LIMIT )); then
      >&2 echo "Limit exceeded."
      exit 1
    fi

    echo "Persistent volume ${PVC_ID} in the process of being removed..."
    sleep 1
    (( ++COUNT ))
  done
done
