#!/usr/bin/env bash

set -e

# This hook restarts the airbyte-worker pods if they were not restarted
# during the latest airbyte's release sync. This helps to resolve an issue
# when the airbyte-worker uses a revoked airbyte-admin ServiceAccount (https://github.com/airbytehq/airbyte/issues/7211).
# This happens because the airbyte's charts are implemented in such a way that
# the airbyte-admin ServiceAccount is recreated each time even if there were no
# changes in any of the airbyte components. As a result we have the airbyte-worker pod
# using the old ServiceAccount that has been already revoked. This leads to crashes
# during the airbyte's operations when it tries to create new pods. After a restart
# the airbyte-worker pod begins using the actual ServiceAccount.
# The hook is intended to be used on the postsync event of the airbyte's release.

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly MAX_DIFF_SECONDS="${3:-60}"

if [[ "${MAX_DIFF_SECONDS}" == "0" ]]; then
  >&2 echo "MAX_DIFF_SECONDS must be more than 0."
  exit 1
fi

readonly POD_SELECTORS="$(kubectl --namespace "${NAMESPACE}" get deployment "${RELEASE_NAME}-worker" --output yaml \
  | yq --unwrapScalar '.spec.selector.matchLabels | to_entries | map("\(.key)=\(.value)") | join(",")')"

readonly PODS_AIRBYTE_WORKERS="$(kubectl --namespace "${NAMESPACE}" get pod --selector="${POD_SELECTORS}" --output yaml \
  | yq --unwrapScalar '.items[] | select(.status.phase == "Running") | .metadata.name')"

# track if rollout was performed (no failed events means rollout happened)
ROLLOUT_PERFORMED="true"

# load all events once to avoid repeated kubectl calls
readonly EVENTS_YAML="$(kubectl --namespace "${NAMESPACE}" get event --output yaml)"
while IFS= read -r POD_NAME; do
  if [[ -z "${POD_NAME}" ]]; then
    continue
  fi

  POD_EVENTS="$(echo "${EVENTS_YAML}" \
    | yq --unwrapScalar '
        .items[]
        | select(.involvedObject.kind == "Pod")
        | select(.involvedObject.name == "'"${POD_NAME}"'")
        | select(.type == "Warning")
        | select(.reason == "Failed")
        | .reason
      ')"

  # if any worker pod contains Failed events — rollout was NOT performed
  if [[ -n "${POD_EVENTS}" ]]; then
    ROLLOUT_PERFORMED="false"
    break
  fi
done <<EOF
${PODS_AIRBYTE_WORKERS}
EOF

# find newest running pod timestamp (latest restart moment)
if [[ "${ROLLOUT_PERFORMED}" == "true" ]]; then
  readonly POD_CREATION_DATETIME="$(
    kubectl --namespace "${NAMESPACE}" get pod --selector="${POD_SELECTORS}" --output yaml \
      | yq --unwrapScalar '
          .items
          | map(select(.status.phase == "Running") | .metadata.creationTimestamp)
          | sort
          | .[-1]
        '
  )"
fi

if [[ "${ROLLOUT_PERFORMED}" == "true" && -n "${POD_CREATION_DATETIME}" ]]; then
  # get SA creation timestamp (it always gets recreated by the chart)
  readonly SA_CREATION_DATETIME="$(kubectl --namespace "${NAMESPACE}" get serviceaccount "${RELEASE_NAME}-admin" --output yaml \
    | yq --unwrapScalar '.metadata.creationTimestamp')"

  # convert timestamps to epoch seconds
  readonly POD_CREATION_TIMESTAMP="$(echo "${POD_CREATION_DATETIME}" | yq --unwrapScalar 'fromdateiso8601')"
  readonly SA_CREATION_TIMESTAMP="$(echo "${SA_CREATION_DATETIME}" | yq --unwrapScalar 'fromdateiso8601')"

  readonly DIFF_SECONDS=$(( SA_CREATION_TIMESTAMP - POD_CREATION_TIMESTAMP ))
  echo "Timestamp difference: ${DIFF_SECONDS} seconds."

  # if worker pod started BEFORE the new ServiceAccount → force restart
  if (( DIFF_SECONDS > MAX_DIFF_SECONDS )); then
    echo "Forcing rolling update of ${RELEASE_NAME}-worker..."
    kubectl --namespace "${NAMESPACE}" rollout restart deployment "${RELEASE_NAME}-worker"
    kubectl --namespace "${NAMESPACE}" rollout status deployment "${RELEASE_NAME}-worker"
  fi
fi
