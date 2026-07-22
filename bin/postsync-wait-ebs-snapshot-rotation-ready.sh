#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly LIMIT="${3:-180}"

function check_ebs_snapshot_rotation() {
  local OUTPUT="${1}"

  if [[ "${OUTPUT}" != "true" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "$(basename "${0}"): Wait timeout exceeded."
    exit 1
  else
    echo
    kubectl --namespace "${NAMESPACE}" get ebssnapshotrotation "${RELEASE_NAME}"
    exit 0
  fi
}

COUNT=1
while true; do
  check_ebs_snapshot_rotation "$(kubectl --namespace "${NAMESPACE}" get ebssnapshotrotation "${RELEASE_NAME}" --output yaml | yq ".status.phase == \"Completed\"")"
done
