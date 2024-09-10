#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

readonly NAMESPACE="kube-system"
readonly RELEASE_NAME="ebs-csi-snapshot-scheduler"

readonly CRD_NAME="snapshotschedules.snapscheduler.backube"
readonly CRD_ANNOTATIONS="meta.helm.sh/release-namespace=${NAMESPACE} meta.helm.sh/release-name=${RELEASE_NAME}"
readonly CRD_LABELS="app.kubernetes.io/managed-by=Helm"

echo "Checking whether ${RELEASE_NAME} release installed..."
if [[ "$(rmk --log-level error release list -l "app=${RELEASE_NAME}" --output json | yq '.[0].installed')" != "true" ]]; then
  echo "Skipped."
  exit
fi

echo "Fixing annotations and labels of ${CRD_NAME} CRD of ${RELEASE_NAME} release..."
kubectl -n "${NAMESPACE}" annotate --overwrite customresourcedefinition "${CRD_NAME}" ${CRD_ANNOTATIONS}
kubectl -n "${NAMESPACE}" label --overwrite customresourcedefinition "${CRD_NAME}" ${CRD_LABELS}
