#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
CLUSTER_NAME="${2}"
CLUSTER_NAMESPACE="${3}"
USERNAME="${4}"
DATABASES=("${5}")
ENABLE_DEFAULT_USERS="${6:-false}"

function create_default_user() {
  for DB in "${DATABASES[@]}"; do
    local DEFAULT_OWNER_USER="${DB}_owner_user"
    local SECRET_PREFIX="${DEFAULT_OWNER_USER//_/-}.${CLUSTER_NAME}"

    # Check secret existence without grep
    if ! (kubectl --namespace "${NAMESPACE}" get secret --output yaml \
      | yq --exit-status ".items[].metadata.name | select(startswith(\"${SECRET_PREFIX}\"))" > /dev/null); then
      kubectl --namespace "${CLUSTER_NAMESPACE}" patch postgresql "${CLUSTER_NAME}" --type=merge \
        --patch '{"spec":{"databases":{"'"${DB}"'":"'"${DEFAULT_OWNER_USER}"'"}}}'
      kubectl --namespace "${CLUSTER_NAMESPACE}" patch postgresql "${CLUSTER_NAME}" --type=merge \
        --patch '{"spec":{"preparedDatabases":{"'"${DB}"'":{"defaultUsers":true,"schemas":{"public":{"defaultRoles":false}},"secretNamespace":"'"${NAMESPACE}"'"}}}}'
    fi
  done

  sleep 5
}

function create_custom_user() {
  local SECRET_PREFIX="${NAMESPACE}.${USERNAME//_/-}.${CLUSTER_NAME}"

  if ! (kubectl --namespace "${NAMESPACE}" get secret --output yaml \
    | yq --exit-status ".items[].metadata.name | select(startswith(\"${SECRET_PREFIX}\"))" > /dev/null); then
    kubectl --namespace "${CLUSTER_NAMESPACE}" patch postgresql "${CLUSTER_NAME}" --type=merge \
      --patch '{"spec":{"users":{"'"${NAMESPACE}"'.'"${USERNAME}"'":["createdb"]}}}'

    for DB in "${DATABASES[@]}"; do
      kubectl --namespace "${CLUSTER_NAMESPACE}" patch postgresql "${CLUSTER_NAME}" --type=merge \
        --patch '{"spec":{"databases":{"'"${DB}"'":"'"${NAMESPACE}"'.'"${USERNAME}"'"}}}'
    done

    sleep 5
  fi
}

function create_user_postgresql() {
  if [[ "${ENABLE_DEFAULT_USERS}" == "true" ]]; then
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
