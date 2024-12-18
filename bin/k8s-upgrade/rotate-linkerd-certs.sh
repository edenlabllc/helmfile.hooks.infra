#!/usr/bin/env bash

set -e

function detect_linkerd() {
  KODJIN_LINKERD_STATUS="$(kubectl get deployment --namespace=fhir-server --output=yaml | \
    yq '.items[] | select(.spec.template.metadata.annotations."linkerd.io/inject" == "'"${1}"'") | .metadata | .name as $n | .namespace += "="+$n | .namespace')"
}

function patch() {
  for MAP in ${1}; do
    MAP="${MAP/=/ }"
    MAP=(${MAP})

    NAMESPACE="${MAP[0]}"
    NAME="${MAP[1]}"

    kubectl patch deployment "${NAME}" --patch='{"spec":{"template":{"metadata":{"annotations":{"linkerd.io/inject": "'"${2}"'"}}}}}' --namespace="${NAMESPACE}"
  done
}

detect_linkerd enabled

patch "${KODJIN_LINKERD_STATUS}" disabled

detect_linkerd disabled

patch "${KODJIN_LINKERD_STATUS}" enabled
