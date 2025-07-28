#!/usr/bin/env bash

set -e

RELEASE_NAME="${1}"
NAMESPACE="${2:-capop-system}"
LIMIT="${3:-1200}"

GO_TEMPLATE='
  {{- range .items -}}
    {{- if eq .kind "Cluster" -}}
      {{- if ne .status.phase "Provisioned" }}0{{- end }}
      {{- if not .status.controlPlaneReady }}0{{- end }}
      {{- if not .status.infrastructureReady }}0{{- end }}
    {{- end -}}
    {{- if eq .kind "K3SCluster" -}}
      {{- if ne .status.phase "Provisioned" }}0{{- end }}
      {{- if not .status.ready }}0{{- end }}
    {{- end -}}
    {{- if eq .kind "K3SControlPlane" -}}
      {{- if ne .status.phase "Provisioned" }}0{{- end }}
      {{- if not .status.ready }}0{{- end }}
      {{- if not .status.initialized }}0{{- end }}
    {{- end -}}
    {{- if eq .kind "K3SRemoteMachine" -}}
      {{- if ne .status.phase "Installed" }}0{{- end }}
      {{- if not .status.ready }}0{{- end -}}
    {{- end -}}
    {{- if eq .kind "Machine" -}}
      {{- if ne .status.phase "Running" }}0{{- end }}
      {{- if not .status.bootstrapReady }}0{{- end }}
      {{- if not .status.infrastructureReady }}0{{- end }}
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
