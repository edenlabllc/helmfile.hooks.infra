#!/usr/bin/env bash

# presync-create-postgres-user.sh
#
# Args:
#   1  app namespace
#   2  postgresql CR name
#   3  postgresql CR namespace
#   4  username (custom path) or ignored (default path)
#   5  space-separated database names
#   6  ENABLE_DEFAULT_USERS (true|false, default false)
#   7  space-separated extension expressions: database:extension:schema
#
# Examples:
#   # dagster — custom user, two DBs, multiple extensions (arg 7 space-separated)
#   presync-create-postgres-user.sh dagster postgres-cluster postgres user "dagster warehouse" false "dagster:vector:public warehouse:pgcrypto:public"
#
#   # airbyte — custom user, three DBs (arg 5 is one space-separated token)
#   presync-create-postgres-user.sh airbyte postgres-cluster postgres user "airbyte temporal temporal_visibility"
#
#   # keycloak-cluster — custom user, DB name from release (dash → underscore)
#   presync-create-postgres-user.sh keycloak postgres-cluster postgres cluster-user keycloak_cluster

set -e

readonly NAMESPACE="${1}"
readonly CLUSTER_NAME="${2}"
readonly CLUSTER_NAMESPACE="${3}"
readonly USERNAME="${4}"
readonly DATABASES=(${5})
readonly ENABLE_DEFAULT_USERS="${6:-false}"
readonly EXTENSIONS=(${7})

function create_default_user() {
  local DB
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

  # wait till postgresql CR really updated
  sleep 5
}

function create_custom_user() {
  local SECRET_PREFIX="${NAMESPACE}.${USERNAME//_/-}.${CLUSTER_NAME}"

  if ! (kubectl --namespace "${NAMESPACE}" get secret --output yaml \
    | yq --exit-status ".items[].metadata.name | select(startswith(\"${SECRET_PREFIX}\"))" > /dev/null); then
    kubectl --namespace "${CLUSTER_NAMESPACE}" patch postgresql "${CLUSTER_NAME}" --type=merge \
      --patch '{"spec":{"users":{"'"${NAMESPACE}"'.'"${USERNAME}"'":["createdb"]}}}'

    local DB
    for DB in "${DATABASES[@]}"; do
      kubectl --namespace "${CLUSTER_NAMESPACE}" patch postgresql "${CLUSTER_NAME}" --type=merge \
        --patch '{"spec":{"databases":{"'"${DB}"'":"'"${NAMESPACE}"'.'"${USERNAME}"'"}}}'
    done

    sleep 5
  fi

  local EXTENSION_EXPR EXTENSION_DATABASE EXTENSION_NAME EXTENSION_SCHEMA
  for EXTENSION_EXPR in "${EXTENSIONS[@]}"; do
    IFS=':' read -r EXTENSION_DATABASE EXTENSION_NAME EXTENSION_SCHEMA <<< "${EXTENSION_EXPR}"
    kubectl --namespace "${CLUSTER_NAMESPACE}" patch postgresql "${CLUSTER_NAME}" --type=merge \
      --patch '{"spec":{"preparedDatabases":{"'"${EXTENSION_DATABASE}"'":{"extensions":{"'"${EXTENSION_NAME}"'":"'"${EXTENSION_SCHEMA}"'"},"schemas":{"public":{"defaultRoles":false,"defaultUsers":false}}}}}}'
  done
}

function create_postgres_user() {
  if [[ "${ENABLE_DEFAULT_USERS}" == "true" ]]; then
    create_default_user
    return 0
  fi

  create_custom_user
}

if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  kubectl create namespace "${NAMESPACE}"
fi

create_postgres_user
