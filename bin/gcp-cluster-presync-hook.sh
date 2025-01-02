#!/usr/bin/env bash

set -e

NAMESPACE="${1:-gcp}"
REGISTRY="${2}"
VERSION="${3}"

readonly CONTROLLER_MANAGER_NAME=capg-controller-manager
readonly CONTROLLER_MANAGER_CONTAINER_NAME=manager

if [[ -n "${REGISTRY}" && -n "${VERSION}" ]]; then
  IMAGE="${REGISTRY}:${VERSION}"
else
  exit 0
fi

if (kubectl --namespace "${NAMESPACE}" get deployment "${CONTROLLER_MANAGER_NAME}" &> /dev/null); then
  CURRENT_IMAGE=$(kubectl --namespace "${NAMESPACE}" get deployment "${CONTROLLER_MANAGER_NAME}" --output yaml \
    | yq '.spec.template.spec.containers[] | select(.name == "'"${CONTROLLER_MANAGER_CONTAINER_NAME}"'") | .image')

  if [[ "${CURRENT_IMAGE}" != "${IMAGE}" ]]; then
    kubectl --namespace "${NAMESPACE}" \
      set image deployment "${CONTROLLER_MANAGER_NAME}" "${CONTROLLER_MANAGER_CONTAINER_NAME}=${IMAGE}"
    kubectl --namespace "${NAMESPACE}" rollout status deployment "${CONTROLLER_MANAGER_NAME}"
  fi
fi
