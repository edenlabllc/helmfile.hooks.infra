#!/usr/bin/env bash

set -e

NAMESPACE=${1}
PG_DB_NAMES=("${2}")
PG_DB_USERNAME="${3}"
PG_CLUSTER_NAME="${4:-postgres-cluster}"
PG_NAMESPACE="${5:-postgres}"
PG_CRD_NAME="${6:-postgresql}"
PG_ENABLE_DEFAULT_USERS="${7:-false}"

function create_default_user() {
  for DB in ${PG_DB_NAMES[*]}; do
    local DEFAULT_OWNER_USER="${DB}_owner_user"
    if ! (kubectl --namespace "${NAMESPACE}" get secret | grep "^${DEFAULT_OWNER_USER//_/-}\.${PG_CLUSTER_NAME}" &> /dev/null); then #todo remove grep
      kubectl --namespace "${PG_NAMESPACE}" patch "${PG_CRD_NAME}" "${PG_CLUSTER_NAME}" --type='merge' \
        -p '{"spec":{"databases":{"'"${DB}"'":"'"${DEFAULT_OWNER_USER}"'"}}}'
      kubectl --namespace "${PG_NAMESPACE}" patch "${PG_CRD_NAME}" "${PG_CLUSTER_NAME}" --type='merge' \
        -p '{"spec":{"preparedDatabases":{"'"${DB}"'":{"defaultUsers":true,"schemas":{"public":{"defaultRoles":false}},"secretNamespace":"'"${NAMESPACE}"'"}}}}'
    fi
  done

  sleep 5
}

function create_custom_user() {
  if ! (kubectl --namespace "${NAMESPACE}" get secret | grep "^${NAMESPACE}\.${PG_DB_USERNAME//_/-}\.${PG_CLUSTER_NAME}" &> /dev/null); then #todo remove grep
    kubectl --namespace "${PG_NAMESPACE}" patch "${PG_CRD_NAME}" "${PG_CLUSTER_NAME}" --type='merge' \
      -p '{"spec":{"users":{"'"${NAMESPACE}"'.'"${PG_DB_USERNAME}"'":["createdb"]}}}'
    for DB in ${PG_DB_NAMES[*]}; do
      kubectl --namespace "${PG_NAMESPACE}" patch "${PG_CRD_NAME}" "${PG_CLUSTER_NAME}" --type='merge' \
        -p '{"spec":{"databases":{"'"${DB}"'":"'"${NAMESPACE}"'.'"${PG_DB_USERNAME}"'"}}}'
    done

    sleep 5
  fi
}

function create_user_postgresql() {
  if [[ "${PG_ENABLE_DEFAULT_USERS}" == "true" ]]; then
    create_default_user
    return 0
  fi

  create_custom_user
}

if ! (kubectl get namespace "${NAMESPACE}" &> /dev/null); then
  kubectl create namespace "${NAMESPACE}"
  create_user_postgresql
else
  create_user_postgresql
fi
