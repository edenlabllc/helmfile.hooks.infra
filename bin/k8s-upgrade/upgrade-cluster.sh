#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

export AWS_PROFILE="$(rmk -ll error config view | yq '.aws.profile')"
export AWS_CONFIG_FILE="${HOME}/.aws/config_${AWS_PROFILE}"
export AWS_SHARED_CREDENTIALS_FILE="${HOME}/.aws/credentials_${AWS_PROFILE}"

readonly NAME="$(rmk -ll error config view | yq '.name')"
CLUSTER_NAME="$(rmk -ll error config view | yq '.exported-vars.env.CLUSTER_NAME')"
if [[ "${CLUSTER_NAME}" == "null" ]]; then
  CLUSTER_NAME="${NAME}-eks"
fi
CURRENT_CLUSTER_VERSION="$(eksctl get cluster --name "${CLUSTER_NAME}" -o yaml | yq '.[0].Version')"

readonly NAMESPACE="kube-system"
readonly KUBE_PROXY_RELEASE_NAME="kube-proxy"
readonly COREDNS_RELEASE_NAME="coredns"

# https://docs.aws.amazon.com/eks/latest/userguide/managing-kube-proxy.html
KUBE_PROXY_IMAGE_PREFIX="$(kubectl -n "${NAMESPACE}" get daemonset "${KUBE_PROXY_RELEASE_NAME}" -o yaml | yq '.spec.template.spec.containers[0].image')"
KUBE_PROXY_IMAGE_PREFIX="${KUBE_PROXY_IMAGE_PREFIX%:*}"
# https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html
COREDNS_IMAGE_PREFIX="$(kubectl -n "${NAMESPACE}" get deployment "${COREDNS_RELEASE_NAME}" -o yaml | yq '.spec.template.spec.containers[0].image')"
COREDNS_IMAGE_PREFIX="${COREDNS_IMAGE_PREFIX%:*}"

# https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
# https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
function upgrade_cluster() {
  local DESIRED_CLUSTER_VERSION="${1}"
  local KUBE_PROXY_VERSION="${2}"
  local COREDNS_VERSION="${3}"

  echo
  echo "Current cluster version: ${CURRENT_CLUSTER_VERSION}"
  echo "Desired cluster version: ${DESIRED_CLUSTER_VERSION}"
  if [[ "${CURRENT_CLUSTER_VERSION//./,}" -ge "${DESIRED_CLUSTER_VERSION//./,}" ]]; then
    echo "No control plane upgrade needed."
  else
    eksctl upgrade cluster --name "${CLUSTER_NAME}" --version "${DESIRED_CLUSTER_VERSION}" --approve
    CURRENT_CLUSTER_VERSION="${DESIRED_CLUSTER_VERSION}"
  fi

  if [[ "${CURRENT_CLUSTER_VERSION//./,}" -eq "${DESIRED_CLUSTER_VERSION//./,}" ]]; then
    kubectl -n "${NAMESPACE}" set image daemonset "${KUBE_PROXY_RELEASE_NAME}" kube-proxy="${KUBE_PROXY_IMAGE_PREFIX}:${KUBE_PROXY_VERSION}"
    kubectl -n "${NAMESPACE}" rollout status daemonset "${KUBE_PROXY_RELEASE_NAME}"
    kubectl -n "${NAMESPACE}" set image deployment "${COREDNS_RELEASE_NAME}" coredns="${COREDNS_IMAGE_PREFIX}:${COREDNS_VERSION}"
    kubectl -n "${NAMESPACE}" rollout status deployment "${COREDNS_RELEASE_NAME}"
  fi
}
