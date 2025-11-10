#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
RELEASE_NAME="${2}"
PATCH_PGHOST_VAR="${3:-false}"
LIMIT="${4:-600}"

COUNT=1

function prepare_pgbouncer() {
  local POOLER_NAME="${1}"
  local SVC_NAME="${2}"

  echo
  if ! (kubectl --namespace "${NAMESPACE}" get deployment "${POOLER_NAME}" &> /dev/null); then
    echo "Pooler ${POOLER_NAME} not enabled."
    echo "Skipped."
    return
  fi

  local POOLER_YAML="$(kubectl --namespace "${NAMESPACE}" get deployment "${POOLER_NAME}" --output yaml)"
  local POOLER_MINIMAL_REPLICAS=1
  local POOLER_CURRENT_REPLICAS="$(echo "${POOLER_YAML}" | yq '.spec.replicas')"

  if [[ "$(echo "${POOLER_YAML}" | yq '.spec.template.metadata.annotations["prometheus.io/scrape"]')" == "true" ]]; then
    echo "Scaling ${POOLER_NAME} replicas to ${POOLER_MINIMAL_REPLICAS} to avoid pending pods during rolling update..."
    kubectl --namespace "${NAMESPACE}" scale deployment "${POOLER_NAME}" --replicas="${POOLER_MINIMAL_REPLICAS}"
    kubectl --namespace "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"

    echo "Disabling ${POOLER_NAME} metrics scraping..."
    kubectl --namespace "${NAMESPACE}" patch deployment "${POOLER_NAME}" --type='merge' \
      -p '{"spec": {"template": {"metadata": {"annotations": {"prometheus.io/scrape": "false"}}}}}'
    kubectl --namespace "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"

    if [[ "${PATCH_PGHOST_VAR}" == "true" ]]; then
      echo "Patching ${POOLER_NAME} PGHOST env..."
      kubectl --namespace "${NAMESPACE}" patch deployment "${POOLER_NAME}" --type='strategic' \
        -p '{"spec":{"template":{"spec":{"containers":[{"name":"connection-pooler","env":[{"name":"PGHOST","value":"'${SVC_NAME}'.'${NAMESPACE}'.svc.cluster.local"}]}]}}}}'
      kubectl --namespace "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"
    fi

    echo "Scaling ${POOLER_NAME} replicas back to ${POOLER_CURRENT_REPLICAS}..."
    kubectl --namespace "${NAMESPACE}" scale deployment "${POOLER_NAME}" --replicas="${POOLER_CURRENT_REPLICAS}"
    kubectl --namespace "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"
  else
    echo "Metrics scraping for ${POOLER_NAME} not enabled or already disabled."
    echo "Skipped."
  fi
}

while true; do
  sleep 1
  STATUS="$(kubectl --namespace "${NAMESPACE}" get postgresql "${RELEASE_NAME}" --output yaml | yq '.status.PostgresClusterStatus')"
  if [[ "${STATUS}" == "null" ]]; then
    echo "Resource postgresql cluster ${RELEASE_NAME} not exist."
    break
  elif [[ "${STATUS}" != "Running" && "${COUNT}" -le "${LIMIT}" ]]; then
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    kubectl --namespace "${NAMESPACE}" get postgresql "${RELEASE_NAME}"
    break
  fi
done

prepare_pgbouncer "${RELEASE_NAME}-pooler" "${RELEASE_NAME}"
prepare_pgbouncer "${RELEASE_NAME}-pooler-repl" "${RELEASE_NAME}-repl"
