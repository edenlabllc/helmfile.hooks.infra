#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1:?Error: Please specify the namespace as the first argument. Example: $0 my-namespace}"
readonly LIMIT="${2:-300}"
readonly SLEEP_INTERVAL=15

readonly CR_STAGES=(
  "keycloakrealms.config.idp.edenlab.io"
  "keycloakauthflows.config.idp.edenlab.io"
  "keycloakcomponents.config.idp.edenlab.io"
  "keycloakclients.config.idp.edenlab.io"
  "keycloakscopemappings.config.idp.edenlab.io"
  "keycloakusers.config.idp.edenlab.io"
)

wait_for_cr_type() {
  local cr_type="$1"
  local elapsed=0

  echo "===> [Stage] Checking CR: ${cr_type}"

  while true; do
    local json
    json=$(kubectl --namespace "${NAMESPACE}" get "${cr_type}" -o json 2>/dev/null || echo '{"items":[]}')

    local total
    total=$(echo "${json}" | yq '.items | length')

    if [[ "${total}" -eq 0 ]]; then
      echo "  [i] No ${cr_type} resources found in namespace '${NAMESPACE}'. Skipping stage."
      echo "--------------------------------------------------------"
      return 0
    fi

    local ready_count
    ready_count=$(echo "${json}" | yq '[.items[] | select(.status.phase == "Completed")] | length')

    echo "  [>] Progress (${cr_type}): ${ready_count}/${total} ready"

    if [[ "${ready_count}" -eq "${total}" ]]; then
      echo "  [✓] Success! All ${cr_type} resources are in 'Completed' status."
      echo "--------------------------------------------------------"
      return 0
    fi

    if [[ "${elapsed}" -ge "${LIMIT}" ]]; then
      >&2 echo "ERROR: Timeout exceeded (${LIMIT}s) while waiting for ${cr_type}!"

      echo "===> Details of unready resources (${cr_type}):"
      echo "${json}" | yq '.items[] | select(.status.phase != "Completed") | "CR: " + .metadata.name + " | Status: " + (.status.phase // "null") + " | Failure count: " + (.status.failureCount // "0")'

      exit 1
    fi

    sleep "${SLEEP_INTERVAL}"
    (( elapsed += SLEEP_INTERVAL ))
  done
}

echo "Starting Keycloak CR status check in namespace: ${NAMESPACE}"
echo "Timeout per stage: ${LIMIT} seconds"
echo "--------------------------------------------------------"

for cr in "${CR_STAGES[@]}"; do
  wait_for_cr_type "${cr}"
done

echo "SUCCESS: Keycloak CR status check completed successfully!"
