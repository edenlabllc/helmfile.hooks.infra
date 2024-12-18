#!/usr/bin/env bash

set -e

RELEASE_NAME="${1:-aws-iam-config}"
NAMESPACE="${2:-capa-system}"
LIMIT="${3:-120}"

GO_TEMPLATE='
  {{- range .items }}
    {{- if not .status }}0{{- end }}
    {{- range .status.conditions }}
      {{- if ne .status "True" }}0{{- end }}
    {{- end }}
  {{- end -}}
'

COUNT=1

K8S_API_GROUP="iam.services.k8s.aws"
K8S_RESOURCES=("group" "instanceprofile" "openidconnectprovider" "role" "policy" "user")
K8S_RESOURCES=("${K8S_RESOURCES[@]/%/.${K8S_API_GROUP}}") # add ".${K8S_API_GROUP}" suffix to each array item
# shellcheck disable=SC2178
K8S_RESOURCES="$(IFS=,; echo "${K8S_RESOURCES[*]}")" # join array by ","

while true; do
  STATUS="$(kubectl -n "${NAMESPACE}" get "${K8S_RESOURCES}" -l "app.kubernetes.io/instance=${RELEASE_NAME}" -o "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >2& echo "Limit exceeded."
    exit 1
  else
    echo
    kubectl -n "${NAMESPACE}" get "${K8S_RESOURCES}" -l "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done
