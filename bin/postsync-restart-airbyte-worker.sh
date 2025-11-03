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
      *)          MACHINE="UNKNOWN:${UNAME_OUT}"
  esac
  echo "${MACHINE}"
}

OS="$(get_os)"
NAMESPACE="${1:-airbyte}"
RELEASE_NAME="${2:-airbyte}"
# default: 1min
ALLOWED_TIME_SEC="${3:-60}"
HAS_ROLLOUT="true"

if [[ -z "${ALLOWED_TIME_SEC}" || "${ALLOWED_TIME_SEC}" == "0" ]] ; then
  echo "ALLOWED_TIME_SEC must be more than 0";
fi

# GET SELECTOR OF PODS
SELECTORS="$(kubectl get deployment -n "${NAMESPACE}" "${RELEASE_NAME}-worker" --output="json" | yq -j '.spec.selector.matchLabels | to_entries | .[] | "\(.key)=\(.value),"')"
SELECTORS="$(echo "${SELECTORS}" | sed 's/,*$//g')" # TRIM SYMBOLS

PODS_AIRBYTE_WORKERS="$(kubectl get pods -n "${NAMESPACE}" -o jsonpath="{.items[*].metadata.name}" --selector="${SELECTORS}" --field-selector="status.phase=Running")"

# HAS RUN PROCESSING ROLLOUT
POD_CREATION_TIMESTAMP=""
for POD_NAME in ${PODS_AIRBYTE_WORKERS}; do
  POD_EVENTS="$(kubectl get events -n "${NAMESPACE}" --field-selector="involvedObject.kind=Pod,involvedObject.name=${POD_NAME},type=Warning,reason=Failed" --chunk-size=1 -o jsonpath="{.items[*].reason}")"
  if [[ ! -z "${POD_EVENTS}" ]]; then
    HAS_ROLLOUT="false"
    break
  fi

  CURRENT_POD_CREATION_TIMESTAMP="$(kubectl get pods -n "${NAMESPACE}" "${POD_NAME}" -o jsonpath="{.metadata.creationTimestamp}")"
  if [[ "${CURRENT_POD_CREATION_TIMESTAMP}" > "${POD_CREATION_TIMESTAMP}" ]]; then
    POD_CREATION_TIMESTAMP="${CURRENT_POD_CREATION_TIMESTAMP}"
  fi
done

if [[ "${HAS_ROLLOUT}" == "true" ]] && [[ ! -z "${POD_CREATION_TIMESTAMP}" ]]; then
  SA_CREATION_TIMESTAMP="$(kubectl get sa -n "${NAMESPACE}" "${RELEASE_NAME}-admin" -o jsonpath="{.metadata.creationTimestamp}")"

  if [[ "${OS}" == "Linux" ]]; then
    POD_DATE="$(date -d "$(echo ${POD_CREATION_TIMESTAMP} | sed 's/T/ /; s/Z//')" "+%s")"
    SA_DATE="$(date -d "$(echo ${SA_CREATION_TIMESTAMP} | sed 's/T/ /; s/Z//')" "+%s")"
  elif [[ "${OS}" == "Mac" ]]; then
    POD_DATE="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "${POD_CREATION_TIMESTAMP}" "+%s")"
    SA_DATE="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "${SA_CREATION_TIMESTAMP}" "+%s")"
  else
    echo "Not supported OS ${OS}. Supported: (Mac|Linux)"
    exit 1
  fi

  DIFF_SEC="$((SA_DATE - POD_DATE))"
  echo "Diff of timestamps: ${DIFF_SEC} seconds"

  HAS_ROLLING="$((DIFF_SEC > ALLOWED_TIME_SEC))"
  if [[ -z "${HAS_ROLLING}" || "${HAS_ROLLING}" == "1" ]]; then
    echo "Forcing rolling update of ${RELEASE_NAME} resources ${RELEASE_NAME}-worker..."
    kubectl -n "${NAMESPACE}" rollout restart deployment "${RELEASE_NAME}-worker"
    kubectl -n "${NAMESPACE}" rollout status deployment "${RELEASE_NAME}-worker"
  fi
fi
