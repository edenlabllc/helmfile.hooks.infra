#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
ALL_ARGS=("${@}")
LAST_ARG="${ALL_ARGS[-1]}"

# Check if last argument is a number (LIMIT), if not use default
if [[ "${LAST_ARG}" =~ ^[0-9]+$ ]]; then
    LIMIT="${LAST_ARG}"
    # Labels are all arguments except NAMESPACE (${1}) and LIMIT (last)
    LABELS=("${ALL_ARGS[@]:1:$((${#ALL_ARGS[@]}-2))}")
else
    LIMIT="120"
    # Labels are all arguments except NAMESPACE (${1})
    LABELS=("${ALL_ARGS[@]:1}")
fi

# Convert array to comma-separated string for selector
LABELS_STR="$(IFS=','; echo "${LABELS[*]}")"
mapfile -t PVC_IDS < <(kubectl --namespace "${NAMESPACE}" get persistentvolumeclaim --selector "${LABELS_STR}" --output yaml | yq --unwrapScalar '.items[].spec.volumeName')

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
