#!/usr/bin/env bash

set -e

CNI_RELEASE_NAME="${1:-aws-vpc-cni}"
CNI_RELEASE_ENABLED="${2:-false}"
CNI_RESOURCE_NAME="${3:-aws-node}"
CNI_CONFIGMAP_NAME="${4:-amazon-vpc-cni}"

function set_annotations() {
  echo "Setting annotations and labels on ${1}/${2}..."
  kubectl -n kube-system annotate --overwrite "${1}" "${2}" meta.helm.sh/release-name="${CNI_RELEASE_NAME}"
  kubectl -n kube-system annotate --overwrite "${1}" "${2}" meta.helm.sh/release-namespace=kube-system
  kubectl -n kube-system label --overwrite "${1}" "${2}" app.kubernetes.io/managed-by=Helm
}

if [[ "${CNI_RELEASE_ENABLED}" == "true" ]]; then
  for KIND in daemonSet clusterRole clusterRoleBinding serviceAccount configMap; do
    if (kubectl get "${KIND}" "${CNI_RESOURCE_NAME}" -n kube-system &> /dev/null); then
      set_annotations "${KIND}" "${CNI_RESOURCE_NAME}"
    elif (kubectl get "${KIND}" "${CNI_CONFIGMAP_NAME}" -n kube-system &> /dev/null); then
      set_annotations "${KIND}" "${CNI_CONFIGMAP_NAME}"
    fi
  done
fi
