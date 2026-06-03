#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"

for CRD in ingressroutes.traefik.containo.us middlewares.traefik.containo.us; do
  if (kubectl get customresourcedefinitions "${CRD}" >/dev/null 2>&1); then
    kubectl --namespace "${NAMESPACE}" delete "${CRD}" \
      --selector "app.kubernetes.io/instance=${RELEASE_NAME}" \
      --ignore-not-found=true
  fi
done
