#!/usr/bin/env bash

set -e

while [ -n "$1" ]; do
  case "$1" in
    --limit) shift; LIMIT="$1"; shift;;
    --) shift; break;;
    *) break;;
  esac
done

NAMESPACE=${1:-dagster}
SECRET_NAME_INPUT=${2:-dagster.user.postgres-cluster.credentials.postgresql.acid.zalan.do}
SECRET_NAME_OUTPUT=${3:-dagster-postgresql-secret}
MASKS=(${4})
LIMIT="${LIMIT:-180}"

function check_input_secret_exist() {
  COUNT=0
  while true; do
    if (kubectl -n "${NAMESPACE}" get secrets "${SECRET_NAME_INPUT}" --ignore-not-found | grep "${SECRET_NAME_INPUT}"); then
      break
    fi

    if [[ "${COUNT}" -le "${LIMIT}" ]]; then
      sleep 1
      ((++COUNT))
    else
      >2& echo "Limit exceeded."
      exit 1
    fi
  done
}

function _delete_secret() {
  if (kubectl -n "${NAMESPACE}" get secrets "${SECRET_NAME_OUTPUT}" --ignore-not-found | grep "${NAMESPACE}"); then
    kubectl -n "${NAMESPACE}" delete secrets "${SECRET_NAME_OUTPUT}" --ignore-not-found
  fi
}

function get_secret_keys() {
  check_input_secret_exist
  KUBECTL_FLAGS=""

  for KEY_VAL in "${MASKS[@]}"; do
    OUTPUT=$(kubectl -n "${NAMESPACE}" get secrets "${SECRET_NAME_INPUT}" -o yaml | yq "${KEY_VAL/*=/}" | base64 -D)
    KUBECTL_FLAGS="${KUBECTL_FLAGS} --from-literal=${KEY_VAL/=*/}=${OUTPUT}"
  done
}

function create_secrets() {
  _delete_secret
  get_secret_keys
  kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME_OUTPUT}" ${KUBECTL_FLAGS}
}

create_secrets
