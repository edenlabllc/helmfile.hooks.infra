#!/usr/bin/env bash

set -e

LIMIT="${1:-120}"

PVC_IDS=( "$(kubectl get --all-namespaces='true' pvc --output='yaml' | yq '.items[] | select(.metadata.annotations["volume.kubernetes.io/storage-provisioner"] == "ebs.csi.aws.com") | .spec.volumeName')" )

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
