#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
RELEASE_NAME="${2}"
LIMIT="${3:-180}"

# higher sleep is needed to wait till the operator starts updating the resources
SLEEP=5

# kafka status conditions might also be of type=Warning && status=True which is acceptable as well, e.g.:
# status:
#   clusterId: MHiqPXwfSHGO1y3C11-lbw
#   conditions:
#   - lastTransitionTime: "2022-04-29T12:47:24.824258Z"
#     message: The desired Kafka storage configuration contains changes which are not
#       allowed. As a result, all storage changes will be ignored. Use DEBUG level logging
#       for more information about the detected changes.
#     reason: KafkaStorage
#     status: "True"
#     type: Warning
#   - lastTransitionTime: "2022-04-29T12:47:29.478Z"
#     status: "True"
#     type: Ready
#
# another kafka status during upgrade to higher broker/operator versions:
# status:
#   clusterId: pduk-sk9SziVmwABVWpnRQ
#   conditions:
#     - lastTransitionTime: "2023-09-29T10:14:22.526074050Z"
#       message: An error while trying to determine the possibility of updating Kafka
#         pods
#       reason: ForceableProblem
#       status: "True"
#       type: NotReady
#   observedGeneration: 2
#
# strimzipodset status example:
# status:
#   currentPods: 3
#   observedGeneration: 1
#   pods: 3
#   readyPods: 3
#
# kafkanodepool is not checked for "replicas"
GO_TEMPLATE='
  {{- range .items }}
    {{- if not .status }}0{{- end }}
    {{- with .status.conditions }}
      {{- range . }}
        {{- if eq .type "NotReady" }}0{{- end }}
        {{- if ne .status "True" }}0{{- end }}
      {{- end }}
    {{- end }}
    {{- if ne .kind "KafkaNodePool" }}
      {{- if .status.replicas }}
        {{- if not .status.updatedReplicas }}0{{ else if gt .status.replicas .status.updatedReplicas}}0{{- end }}
        {{- if not .status.readyReplicas }}0{{ else if ne .status.replicas .status.readyReplicas }}0{{- end }}
      {{- end }}
    {{- end }}
    {{- if .status.pods }}
      {{- if not .status.currentPods }}0{{ else if gt .status.pods .status.currentPods}}0{{- end }}
      {{- if not .status.readyPods }}0{{ else if ne .status.pods .status.readyPods }}0{{- end }}
    {{- end }}
  {{- end -}}
'
# initial sleep for the operator
sleep ${SLEEP}

COUNT=1
RESOURCES="deployment,kafka,kafkanodepool,statefulset,strimzipodset"
while true; do
  STATUS="$(kubectl --namespace "${NAMESPACE}" get "${RESOURCES}" --selector "app.kubernetes.io/instance=${RELEASE_NAME}" --output "go-template=${GO_TEMPLATE}")"
  if [[ "${STATUS}" != "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep "${SLEEP}"
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    echo
    kubectl --namespace "${NAMESPACE}" get "${RESOURCES}" --selector "app.kubernetes.io/instance=${RELEASE_NAME}"
    break
  fi
done

# Note: KRaft is alpha in Strimzi 0.39.0 and not recommended to run in production.
#       Old ZooKeeper nodes should be removed manually after a successful migration or the hook should handle this automatically.
