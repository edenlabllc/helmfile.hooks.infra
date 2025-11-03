#!/usr/bin/env bash

set -e

LIMIT="${1:-120}"

COUNT=1
while [[ "$(kubectl get pv --output='yaml' | yq '[.items[] | select(.metadata.annotations["pv.kubernetes.io/provisioned-by"] == "ebs.csi.aws.com")] | length > 0')" == "true" ]]; do
  if (( COUNT > LIMIT )); then
    >&2 echo "Limit exceeded."
    exit 1
  fi

  echo "PV resources in the process of being removed."
  sleep 1
  ((++COUNT))
done
