#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly LIMIT="${3:-300}"
readonly SLEEP_INTERVAL=1

readonly CR_TYPES=(
  "keycloakrealms"
  "keycloakauthflows"
  "keycloakcomponents"
  "keycloakclients"
  "keycloakscopemappings"
  "keycloakusers"
)

wait_for_cr_type() {
  local cr_type="$1"
  local elapsed=0

  echo "Checking CR: ${cr_type}"

  while true; do
    local json
    json=$(kubectl --namespace "${NAMESPACE}" get "${cr_type}" --selector "app.kubernetes.io/instance=${RELEASE_NAME}" -o json 2>/dev/null || echo '{"items":[]}')

    local total
    total=$(echo "${json}" | yq '.items | length')

    if [[ "${total}" -eq 0 ]]; then
      echo "No ${cr_type} resources found in namespace '${NAMESPACE}'. Skipping."
      return 0
    fi

    local ready_count
    ready_count=$(echo "${json}" | yq '[.items[] | select(.status.phase == "Completed")] | length')

    echo "Progress (${cr_type}): ${ready_count}/${total} ready"

    if [[ "${ready_count}" -eq "${total}" ]]; then
      echo "Success! All ${cr_type} resources are in 'Completed' status."
      return 0
    fi

    if [[ "${elapsed}" -ge "${LIMIT}" ]]; then
      >&2 echo "ERROR: Timeout exceeded (${LIMIT}s) while waiting for ${cr_type}!"

      echo "Details of unready resources (${cr_type}):"
      echo "${json}" | yq '.items[] | select(.status.phase != "Completed") | "CR: " + .metadata.name + " | Status: " + (.status.phase // "null") + " | Failure count: " + (.status.failureCount // "0")'

      exit 1
    fi

    sleep "${SLEEP_INTERVAL}"
    (( elapsed += SLEEP_INTERVAL ))
  done
}

echo "Starting Keycloak CR status check in namespace: ${NAMESPACE}"
echo "Timeout per: ${LIMIT} seconds"

for cr in "${CR_TYPES[@]}"; do
  wait_for_cr_type "${cr}.config.idp.edenlab.io"
done

echo "SUCCESS: Keycloak CR status check completed successfully!"
