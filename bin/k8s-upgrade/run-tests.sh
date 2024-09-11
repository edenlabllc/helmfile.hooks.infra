#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

function test_postgres() {
  local POSTGRES_NAMESPACE="${1}"
  local POSTGRES_RELEASE_NAME="${2}"

  echo
  echo "Checking whether ${POSTGRES_RELEASE_NAME} release installed..."
  if [[ "$(rmk --log-level error release list -l "app=${POSTGRES_RELEASE_NAME}" --output json | yq '.[0].installed')" != "true" ]]; then
    echo "Skipped."
    return
  fi

  # Example output:
  #- Cluster: postgres-cluster
  #  Host: 10.1.2.38
  #  Member: postgres-cluster-0
  #  Role: Leader
  #  State: running
  #  TL: 7
  #- Cluster: postgres-cluster
  #  Host: 10.1.6.248
  #  Lag in MB: 0
  #  Member: postgres-cluster-1
  #  Role: Sync Standby
  #  State: running
  #  TL: 7

  echo "Showing information about Patroni cluster and all the members of ${POSTGRES_RELEASE_NAME}..."
  POSTGRES_CLUSTER_LIST="$(kubectl -n "${POSTGRES_NAMESPACE}" exec -it -c postgres "${POSTGRES_RELEASE_NAME}-cluster-0" -- patronictl list -f yaml)"
  echo "${POSTGRES_CLUSTER_LIST}"

  echo "Checking all the members of ${POSTGRES_RELEASE_NAME} are running..."
  if [[ "$(echo "${POSTGRES_CLUSTER_LIST}" | yq '([.[] | select(.State == "running")] | length) == (. | length)')" == "true" ]]; then
    echo "OK."
  else
    >&2 echo "ERROR: Not all the members of ${POSTGRES_RELEASE_NAME} are running."
    exit 1
  fi

  echo "Checking all the members of ${POSTGRES_RELEASE_NAME} have correct roles..."
  if [[ "$(echo "${POSTGRES_CLUSTER_LIST}" | yq '([.[] | select(.Role == "Leader")] | length) == 1')" == "true" ]] \
    && [[ "$(echo "${POSTGRES_CLUSTER_LIST}" | yq '([.[] | select(.Role == "Sync Standby")] | length) == 1')" == "true" ]]; then
    echo "OK."
  else
    >&2 echo "ERROR: The roles of all the members of ${POSTGRES_RELEASE_NAME} are not \"Leader\" and \"Sync Standby\"."
    exit 1
  fi
}

echo "Checking all postgres releases..."
test_postgres "postgres" "postgres"
test_postgres "postgres" "elt-postgres"
test_postgres "postgres" "fhir-postgres"
