#!/usr/bin/env bash

set -e

# One-time copy of a Secret. Creates DST only if it doesn't exist.
# Usage: ./copy-secret-once.sh <SRC_NAMESPACE> <SRC_SECRET> <DST_NAMESPACE> <DST_SECRET>

SRC_NAMESPACE="${1}"
SRC_SECRET_NAME="${2}"
export DST_NAMESPACE="${3}"
export DST_SECRET_NAME="${4}"

if (kubectl get secret --namespace "${DST_NAMESPACE}" "${DST_SECRET_NAME}" >/dev/null 2>&1); then
  echo "Secret ${DST_SECRET_NAME} already exists in namespace ${DST_NAMESPACE} — skipping (one-time copy)."
  exit 0
fi

if (kubectl get secret --namespace "${SRC_NAMESPACE}" "${SRC_SECRET_NAME}" >/dev/null 2>&1); then
  kubectl get secret --namespace "${SRC_NAMESPACE}" "${SRC_SECRET_NAME}" --output yaml \
    | yq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences)
    | .metadata.name = env(DST_SECRET_NAME)
    | .metadata.namespace = env(DST_NAMESPACE)' \
    | kubectl create -f -

  echo "Secret ${DST_SECRET_NAME} created in ${DST_NAMESPACE} from ${SRC_SECRET_NAME} in ${SRC_NAMESPACE} (one-time copy)."
else
  echo "Secret ${SRC_SECRET_NAME} does not exist in namespace ${SRC_NAMESPACE} — skipping (one-time copy)."
fi
