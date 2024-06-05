#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

# Note: In future, fhir-postgres, elt-postgres might be added.

readonly POSTGRES_NAMESPACE="postgres"
readonly POSTGRES_RELEASE_NAME="postgres"

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
echo "Showing information about Patroni cluster and its members of ${POSTGRES_RELEASE_NAME}..."
readonly POSTGRES_CLUSTER_LIST="$(kubectl -n "${POSTGRES_NAMESPACE}" exec -it -c postgres "${POSTGRES_RELEASE_NAME}-cluster-0" -- patronictl list -f yaml)"
echo "${POSTGRES_CLUSTER_LIST}"

echo "Checking all the members are running..."
if [[ "$(echo "${POSTGRES_CLUSTER_LIST}" | yq '([.[] | select(.State == "running")] | length) == (. | length)')" == "true" ]]; then
  echo "OK."
else
  >&2 echo "ERROR: Not all the members are running."
  exit 1
fi

echo "Checking all the members have correct roles..."
if [[ "$(echo "${POSTGRES_CLUSTER_LIST}" | yq '([.[] | select(.Role == "Leader")] | length) == 1')" == "true" ]] \
  && [[ "$(echo "${POSTGRES_CLUSTER_LIST}" | yq '([.[] | select(.Role == "Sync Standby")] | length) == 1')" == "true" ]]; then
  echo "OK."
else
  >&2 echo "ERROR: The roles are not \"Leader\" and \"Sync Standby\"."
  exit 1
fi
