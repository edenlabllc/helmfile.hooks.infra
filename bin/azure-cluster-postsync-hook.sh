#!/usr/bin/env bash

set -e

while [ -n "$1" ]; do
  case "$1" in
    --limit) shift; LIMIT="$1"; shift;;
    --) shift; break;;
    *) break;;
  esac
done

RELEASE_NAME="${1}"
NAMESPACE="${2:-azure}"

LIMIT="${LIMIT:-1200}"

GO_TEMPLATE='
  {{- range .items -}}
    {{- if eq .kind "Cluster" -}}
      {{- if ne .status.phase "Provisioned" }}0{{- end }}
    {{- end -}}
    {{- if eq .kind "AzureManagedCluster" -}}
      {{- if not .status.ready }}0{{- end }}
    {{- end -}}
    {{- if eq .kind "AzureManagedControlPlane" -}}
      {{- if not .status.ready }}0{{- end }}
      {{- if not .status.initialized }}0{{- end }}
    {{- end -}}
    {{- if eq .kind "AzureManagedMachinePool" -}}
      {{- if not .status.ready }}0{{- end -}}
    {{- end -}}
  {{- end -}}
'

COUNT=1
while true; do
  STATUS="$(kubectl --namespace "${NAMESPACE}" get cluster-api \
    --selector "app.kubernetes.io/instance=${RELEASE_NAME}" \
    --output "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >2& echo "Limit exceeded."
    exit 1
  else
    echo
    kubectl --namespace "${NAMESPACE}" get cluster-api --selector "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done
