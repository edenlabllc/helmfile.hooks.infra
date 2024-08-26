#!/usr/bin/env bash

set -e

if [[ "${SKIP_POSTGRES_POSTSYNC_HOOK}" == "true" ]]; then
  echo "Skipped."
  exit 0
fi

CLUSTER_NAME="${1:-postgres-cluster}"
NAMESPACE="${2:-postgres}"
CRD_NAME="${3:-postgresql}"
LIMIT="${4:-600}"

COUNT=1

function disable_pooler_metrics_scraping() {
  local POOLER_NAME="${1}"

  echo
  if ! (kubectl -n "${NAMESPACE}" get deployment "${POOLER_NAME}" &> /dev/null); then
    echo "Pooler ${POOLER_NAME} not enabled."
    echo "Skipped."
    return
  fi

  local POOLER_YAML="$(kubectl -n "${NAMESPACE}" get deployment "${POOLER_NAME}" -o yaml)"
  local POOLER_MINIMAL_REPLICAS=1
  local POOLER_CURRENT_REPLICAS="$(echo "${POOLER_YAML}" | yq '.spec.replicas')"

  if [[ "$(echo "${POOLER_YAML}" | yq '.spec.template.metadata.annotations["prometheus.io/scrape"]')" == "true" ]]; then
    echo "Scaling ${POOLER_NAME} replicas to ${POOLER_MINIMAL_REPLICAS} to avoid pending pods during rolling update..."
    kubectl -n "${NAMESPACE}" scale deployment "${POOLER_NAME}" --replicas="${POOLER_MINIMAL_REPLICAS}"
    kubectl -n "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"

    echo "Disabling ${POOLER_NAME} metrics scraping..."
    kubectl -n "${NAMESPACE}" patch deployment "${POOLER_NAME}" --type='merge' \
      -p '{"spec": {"template": {"metadata": {"annotations": {"prometheus.io/scrape": "false"}}}}}'
    kubectl -n "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"

    echo "Scaling ${POOLER_NAME} replicas back to ${POOLER_CURRENT_REPLICAS}..."
    kubectl -n "${NAMESPACE}" scale deployment "${POOLER_NAME}" --replicas="${POOLER_CURRENT_REPLICAS}"
    kubectl -n "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"
  else
    echo "Metrics scraping for ${POOLER_NAME} not enabled or already disabled."
    echo "Skipped."
  fi
}

while true; do
  sleep 1
  STATUS=$(kubectl -n "${NAMESPACE}" get "${CRD_NAME}" "${CLUSTER_NAME}" -o yaml | yq '.status.PostgresClusterStatus')
  if [[ "${STATUS}" == "null" ]]; then
    echo "Resource ${CRD_NAME} cluster ${CLUSTER_NAME} not exist."
    break
  elif [[ "${STATUS}" != "Running" && "${COUNT}" -le "${LIMIT}" ]]; then
    ((++COUNT))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >2& echo "Limit exceeded."
    exit 1
  else
    kubectl -n "${NAMESPACE}" get "${CRD_NAME}" "${CLUSTER_NAME}"
    break
  fi
done

disable_pooler_metrics_scraping "${CLUSTER_NAME}-pooler"
disable_pooler_metrics_scraping "${CLUSTER_NAME}-pooler-repl"
