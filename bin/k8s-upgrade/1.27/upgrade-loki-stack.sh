#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

readonly NAMESPACE="loki"
readonly RELEASE_NAME="loki-stack"
readonly PROMTAIL_NAME="promtail"

echo "Checking whether ${RELEASE_NAME} release installed..."
if [[ "$(rmk --log-level error release -- -l "app=${RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" != "true" ]]; then
  echo "Skipped."
  exit
fi

# Error log:
# Error: UPGRADE FAILED: cannot patch "loki-stack-promtail" with kind DaemonSet: DaemonSet.apps "loki-stack-promtail" is invalid: spec.selector: Invalid value: v1.LabelSelector{MatchLabels:map[string]string{"app.kubernetes.io/instance":"loki-stack", "app.kubernetes.io/name":"promtail"}, MatchExpressions:[]v1.LabelSelectorRequirement(nil)}: field is immutable

# Old selectors:
# selector:
#   matchLabels:
#     app: promtail
#     release: loki-stack

# New selectors:
# selector:
#   matchLabels:
#     app.kubernetes.io/instance: loki-stack
#     app.kubernetes.io/name: promtail

readonly PROMTAIL_DS_NAME="$(kubectl -n "${NAMESPACE}" get daemonset -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${PROMTAIL_NAME}" -o name)"

if [[ "${PROMTAIL_DS_NAME}" != "" ]]; then
  echo "New daemonset ${RELEASE_NAME}-${PROMTAIL_NAME} already exists."
  echo "Skipped."
  exit
fi

echo "Deleting old daemonset ${RELEASE_NAME}-${PROMTAIL_NAME} without cascade because of changed immutable selector.matchLabels..."
kubectl -n "${NAMESPACE}" delete daemonset --ignore-not-found=true --wait=true "${RELEASE_NAME}-${PROMTAIL_NAME}"
