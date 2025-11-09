#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
K8S_LABELS=("${@}")
LIMIT="120"

if [[ ! "${2}" =~ ^[0-9]+$ ]];then
    K8S_LABELS=("${K8S_LABELS[@]:1}")
else
    LIMIT="${2}"
    K8S_LABELS=("${K8S_LABELS[@]:2}")
fi

# Convert array to comma-separated string for selector
K8S_LABELS_STR="$(IFS=','; echo "${K8S_LABELS[*]}")"
mapfile -t PVC_IDS < <(kubectl --namespace "${NAMESPACE}" get persistentvolumeclaim --selector "${K8S_LABELS_STR}" --output yaml | yq --unwrapScalar '.items[].spec.volumeName')

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
