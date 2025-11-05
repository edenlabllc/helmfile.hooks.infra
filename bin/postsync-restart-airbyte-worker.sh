#!/usr/bin/env bash

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

set -e

function get_os() {
  UNAME_OUT="$(uname -s)"
  case "${UNAME_OUT}" in
      Linux*)     MACHINE="Linux";;
      Darwin*)    MACHINE="Mac";;
      *)          MACHINE="UNKNOWN: ${UNAME_OUT}"
  esac
  echo "${MACHINE}"
}

OS="$(get_os)"
NAMESPACE="${1:-airbyte}"
RELEASE_NAME="${2:-airbyte}"
ALLOWED_TIME_SECONDS="${3:-60}"

if [[ -z "${ALLOWED_TIME_SECONDS}" || "${ALLOWED_TIME_SECONDS}" == "0" ]] ; then
  >&2 echo "ALLOWED_TIME_SEC must be more than 0"
  exit 1
fi

POD_SELECTORS="$(kubectl --namespace "${NAMESPACE}" get deployment "${RELEASE_NAME}-worker" --output yaml \
  | yq --unwrapScalar '.spec.selector.matchLabels | to_entries | map("\(.key)=\(.value)") | join(",")')"

PODS_AIRBYTE_WORKERS="$(kubectl --namespace "${NAMESPACE}" get pod --selector="${POD_SELECTORS}" --output yaml \
  | yq --unwrapScalar '.items[] | select(.status.phase == "Running") | .metadata.name')"

# track if rollout was performed (i.e., if any worker pod crashed)
HAS_ROLLOUT="true"

# load all events once to avoid repeated kubectl calls
EVENTS_YAML="$(kubectl --namespace "${NAMESPACE}" get event --output yaml)"

for POD_NAME in ${PODS_AIRBYTE_WORKERS}; do
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
    HAS_ROLLOUT="false"
    break
  fi
done

# find newest running pod timestamp (latest restart moment)
if [[ "${HAS_ROLLOUT}" == "true" ]]; then
  POD_CREATION_TIMESTAMP="$(
    kubectl --namespace "${NAMESPACE}" get pod --selector="${POD_SELECTORS}" --output yaml \
      | yq --unwrapScalar '
          .items
          | map(select(.status.phase == "Running") | .metadata.creationTimestamp)
          | sort
          | .[-1]
        '
  )"
fi

if [[ "${HAS_ROLLOUT}" == "true" ]] && [[ -n "${POD_CREATION_TIMESTAMP}" ]]; then
  # get SA creation timestamp (it always gets recreated by the chart)
  SA_CREATION_TIMESTAMP="$(kubectl --namespace "${NAMESPACE}" get serviceaccount "${RELEASE_NAME}-admin" --output yaml \
    | yq --unwrapScalar '.metadata.creationTimestamp')"

  # convert timestamps to epoch seconds
  if [[ "${OS}" == "Linux" ]]; then
    POD_DATE="$(date -d "${POD_CREATION_TIMESTAMP}" +%s)"
    SA_DATE="$(date -d "${SA_CREATION_TIMESTAMP}" +%s)"
  elif [[ "${OS}" == "Mac" ]]; then
    POD_DATE="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "${POD_CREATION_TIMESTAMP}" +%s)"
    SA_DATE="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "${SA_CREATION_TIMESTAMP}" +%s)"
  else
    echo "Unsupported OS ${OS}. Supported: (Mac|Linux)"
    exit 1
  fi

  DIFF_SECONDS=$((SA_DATE - POD_DATE))
  echo "Timestamp difference: ${DIFF_SECONDS} seconds"

  # if worker pod started BEFORE the new ServiceAccount → force restart
  if (( DIFF_SECONDS > ALLOWED_TIME_SECONDS )); then
    echo "Forcing rolling update of ${RELEASE_NAME}-worker..."
    kubectl --namespace "${NAMESPACE}" rollout restart deployment "${RELEASE_NAME}-worker"
    kubectl --namespace "${NAMESPACE}" rollout status deployment "${RELEASE_NAME}-worker"
  fi
fi
