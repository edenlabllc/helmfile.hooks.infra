#!/usr/bin/env bash

# postsync-wait-postgres-ready.sh
#
# Args:
#   1  namespace
#   2  release name
#   3  DISABLE_POOLER_METRICS (true|false, default false) — DEPRECATED: remove this arg
#   4  wait timeout in seconds (default 600)
#
# Waits until PostgresClusterStatus == Running, then exits.
#
# Why pooler patching in this hook is off by default
#
# Declarative config replaces the patch — connectionPooler.inheritPodAnnotations: false
# stops pooler pods from inheriting Spilo prometheus.io/* annotations, so there is nothing
# left to strip after sync.
#
# Metrics live elsewhere — PgBouncer is scraped via postgres-pgbouncer-exporter, not pooler
# pod annotations.
#
# Operator owns the Deployment — fork v1.15.2 reconciles pooler image, Linkerd annotations,
# and deploymentStrategy (maxSurge: 0, maxUnavailable: 1) from the CR. Imperative kubectl
# patch/scale fights that loop and can cause extra rollouts or Pending pods on small clusters.
#
# Arg 3 is never passed — DISABLE_POOLER_METRICS defaults to false for all three clusters
# (postgres, elt-postgres, fhir-postgres), so the patch block in the hook never runs anyway.
#
# Bottom line: the old hook was a workaround for inherited scrape annotations; that is fixed
# in values/operator now, so this script only waits for PostgresClusterStatus == Running.
# DEPRECATED: arg 3 and disable_pooler_metrics() should be removed once no callers pass true.

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly DISABLE_POOLER_METRICS="${3:-false}"
readonly LIMIT="${4:-600}"

readonly CLUSTER_NAME="${RELEASE_NAME}-cluster"

COUNT=1

# DEPRECATED: remove disable_pooler_metrics() once arg 3 is dropped.
function disable_pooler_metrics() {
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

    echo "Patching ${POOLER_NAME} PGHOST env..."
    kubectl --namespace "${NAMESPACE}" patch deployment "${POOLER_NAME}" --type='strategic' \
      -p '{"spec":{"template":{"spec":{"containers":[{"name":"connection-pooler","env":[{"name":"PGHOST","value":"'${SVC_NAME}'.'${NAMESPACE}'.svc.cluster.local"}]}]}}}}'
    kubectl --namespace "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"

    echo "Scaling ${POOLER_NAME} replicas back to ${POOLER_CURRENT_REPLICAS}..."
    kubectl --namespace "${NAMESPACE}" scale deployment "${POOLER_NAME}" --replicas="${POOLER_CURRENT_REPLICAS}"
    kubectl --namespace "${NAMESPACE}" rollout status deployment "${POOLER_NAME}"
  else
    echo "Metrics scraping for ${POOLER_NAME} not enabled or already disabled."
    echo "Skipped."
  fi
}

# status.PostgresClusterStatus (Zalando postgres-operator 1.15.1)
#
# Status          | Meaning
# ----------------|----------------------------------------------------------
# Running         | Cluster healthy; operator finished last sync
# Creating        | New cluster being created
# Updating        | In progress — rolling update / major upgrade / spec change
# UpdateFailed    | Update failed — check operator logs
# SyncFailed      | Reconcile failed — check operator logs
# CreateFailed    | Initial create failed
# Invalid         | Invalid spec (e.g. teamId/name mismatch)
# (empty)         | Unknown / not set yet
while true; do
  sleep 1
  STATUS="$(kubectl --namespace "${NAMESPACE}" get postgresql "${CLUSTER_NAME}" --output yaml | yq '.status.PostgresClusterStatus')"
  if [[ "${STATUS}" != "Running" && "${COUNT}" -le "${LIMIT}" ]]; then
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "$(basename "${0}"): Wait timeout exceeded."
    exit 1
  else
    kubectl --namespace "${NAMESPACE}" get postgresql "${CLUSTER_NAME}"
    break
  fi
done

# DEPRECATED: remove this block together with arg 3 and disable_pooler_metrics().
if [[ "${DISABLE_POOLER_METRICS}" == "true" ]]; then
  disable_pooler_metrics "${CLUSTER_NAME}-pooler" "${CLUSTER_NAME}"
  disable_pooler_metrics "${CLUSTER_NAME}-pooler-repl" "${CLUSTER_NAME}-repl"
fi
