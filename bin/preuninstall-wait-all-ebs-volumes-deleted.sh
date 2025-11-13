#!/usr/bin/env bash

set -e

readonly LIMIT="${1:-120}"

COUNT=1
while [[ "$(kubectl get persistentvolume --output='yaml' | yq '[.items[] | select(.metadata.annotations["pv.kubernetes.io/provisioned-by"] == "ebs.csi.aws.com")] | length > 0')" == "true" ]]; do
  if (( COUNT > LIMIT )); then
    >&2 echo "$(basename "${0}"): Wait timeout exceeded."
    exit 1
  fi

  echo "EBS volumes in the process of being removed..."
  sleep 1
  (( ++COUNT ))
done
