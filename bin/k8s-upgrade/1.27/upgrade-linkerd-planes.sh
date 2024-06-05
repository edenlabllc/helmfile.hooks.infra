#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

readonly ELASTIC_NAMESPACE="elastic"
readonly ELASTIC_RELEASE_NAME="elastic"

readonly LINKERD_RELEASE_NAME="linkerd"
readonly LINKERD_STACK_NAME="linkerd"

readonly KAFKA_NAMESPACE="kafka"
readonly KAFKA_RELEASE_NAME="kafka"

readonly POSTGRES_NAMESPACE="postgres"
readonly POSTGRES_RELEASE_NAME="postgres"

readonly REDIS_NAMESPACE="redis"
readonly REDIS_RELEASE_NAME="redis"

readonly ENVIRONMENT="$(rmk -ll error config view | yq '.environment')"

echo "Checking whether old or new ${LINKERD_RELEASE_NAME} releases installed..."
if [[ "$(rmk --log-level error release -- -l "app=${LINKERD_RELEASE_NAME}" -l "app=${LINKERD_RELEASE_NAME}-control-plane" --log-level error list --output json | yq '[.[] | select(.installed == true)] | length > 0')" != "true" ]]; then
  echo "Skipped."
  echo
  echo "Synchronizing all releases..."
  rmk release sync
  exit
fi

ALL_SCOPES_COUNT="$(find etc -depth 1 | wc -l)"
((ALL_SCOPES_COUNT--)) # do not count "cluster" directory
readonly DISABLED_SCOPES_COUNT="$(rmk --log-level error release -- -l app=linkerd --log-level error build | yq '.renderedvalues.configs.linkerd | select(.await == false and .inject == "disabled")' | grep await | wc -l)"

echo
echo "Validating changes to configs.linkerd in the global files..."
if [[ "${ALL_SCOPES_COUNT}" -gt "${DISABLED_SCOPES_COUNT}" ]]; then
  >&2 echo "ERROR: All scopes must have the etc/<scope>/${ENVIRONMENT}/globals.yaml.gotmpl file with linkerd temporary disabled:"
  >&2 echo "configs:"
  >&2 echo "  linkerd:"
  >&2 echo "    await: false"
  >&2 echo "    inject: disabled"
  >&2 echo "Do not commit the changes, they will be auto-reverted later. Update the global files and retry."
  exit 1
fi
echo "OK."

echo
echo "Destroying old ${LINKERD_RELEASE_NAME} releases before disabling await/injection in other services..."
rmk release -- -l "app=${LINKERD_RELEASE_NAME}" -l "app=${LINKERD_RELEASE_NAME}-multicluster" -l "app=service-mirror-watcher" destroy

if [[ "$(rmk --log-level error release -- -l "app=${ELASTIC_RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" == "true" ]]; then
  echo
  echo "Forcing rolling update of ${ELASTIC_RELEASE_NAME}..."
  SKIP_ELASTIC_POSTSYNC_HOOK=true rmk release -- -l "app=${ELASTIC_RELEASE_NAME}-operator" -l "app=${ELASTIC_RELEASE_NAME}" sync
  kubectl -n "${ELASTIC_NAMESPACE}" delete pod -l "elasticsearch.k8s.elastic.co/cluster-name=${ELASTIC_RELEASE_NAME}"
  "$(dirname "${BASH_SOURCE}")/../../elastic-postsync-hook.sh" "${ELASTIC_RELEASE_NAME}" "${ELASTIC_NAMESPACE}"
fi

if [[ "$(rmk --log-level error release -- -l "app=${KAFKA_RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" == "true" ]]; then
  echo
  echo "Forcing rolling update of ${KAFKA_RELEASE_NAME} (needed because of an unsupported update from 2.8.X to 3.5.X)..."
  SKIP_KAFKA_POSTSYNC_HOOK=true rmk release -- -l "app=${KAFKA_RELEASE_NAME}-operator" -l "app=${KAFKA_RELEASE_NAME}" sync
  kubectl -n "${KAFKA_NAMESPACE}" delete pod -l "app.kubernetes.io/instance=${KAFKA_RELEASE_NAME},strimzi.io/name=${KAFKA_RELEASE_NAME}-kafka"
  "$(dirname "${BASH_SOURCE}")/../../kafka-postsync-hook.sh" "${KAFKA_RELEASE_NAME}" "${KAFKA_NAMESPACE}"
fi

if [[ "$(rmk --log-level error release -- -l "app=${POSTGRES_RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" == "true" ]]; then
  echo
  echo "Forcing rolling update of ${POSTGRES_RELEASE_NAME}..."
  SKIP_POSTGRES_POSTSYNC_HOOK=true rmk release -- -l "app=${POSTGRES_RELEASE_NAME}-operator" -l "app=${POSTGRES_RELEASE_NAME}" sync
  kubectl -n "${POSTGRES_NAMESPACE}" delete pod -l "application=spilo,cluster-name=${POSTGRES_RELEASE_NAME}-cluster,linkerd.io/control-plane-ns"
  # store current number of replicas of the connection pooler to rollback to the value after all upgrades"
  POSTGRES_CLUSTER_POOLER_REPLICAS="$(kubectl -n "${POSTGRES_NAMESPACE}" get postgresql "${POSTGRES_RELEASE_NAME}-cluster" -o yaml | yq '.spec.connectionPooler.numberOfInstances')"
  kubectl -n "${POSTGRES_NAMESPACE}" scale deployment "${POSTGRES_RELEASE_NAME}-cluster-pooler" --replicas=0
  kubectl -n "${POSTGRES_NAMESPACE}" scale deployment "${POSTGRES_RELEASE_NAME}-cluster-pooler" --replicas="${POSTGRES_CLUSTER_POOLER_REPLICAS}"
  kubectl -n "${POSTGRES_NAMESPACE}" rollout status deployment "${POSTGRES_RELEASE_NAME}-cluster-pooler"
  "$(dirname "${BASH_SOURCE}")/../../postgres-postsync-hook.sh"
fi

if [[ "$(rmk --log-level error release -- -l "app=${REDIS_RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" == "true" ]]; then
  echo
  echo "Forcing rolling update of ${REDIS_RELEASE_NAME}..."
  kubectl -n "${REDIS_NAMESPACE}" delete pod -l "app.kubernetes.io/instance=${REDIS_RELEASE_NAME},app.kubernetes.io/component=replica,linkerd.io/control-plane-ns"
  kubectl -n "${REDIS_NAMESPACE}" rollout status statefulset "${REDIS_RELEASE_NAME}-replicas"
fi

echo
echo "Synchronizing all releases except new ${LINKERD_STACK_NAME} stack..."
rmk release -- -l "stack!=${LINKERD_STACK_NAME}" sync

echo
echo "Resetting all changes to the global files..."
git restore etc/*/*/globals.yaml.gotmpl
git status

echo
echo "Synchronizing new ${LINKERD_STACK_NAME} stack..."
rmk release -- -l "stack=${LINKERD_STACK_NAME}" sync

if [[ "$(rmk --log-level error release -- -l "app=${ELASTIC_RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" == "true" ]]; then
  echo
  echo "Synchronizing ${ELASTIC_RELEASE_NAME}..."
  SKIP_ELASTIC_POSTSYNC_HOOK=true rmk release -- -l "app=${ELASTIC_RELEASE_NAME}-operator" -l "app=${ELASTIC_RELEASE_NAME}" sync
  kubectl -n "${ELASTIC_NAMESPACE}" delete pod -l "elasticsearch.k8s.elastic.co/cluster-name=${ELASTIC_RELEASE_NAME}"
  "$(dirname "${BASH_SOURCE}")/../../elastic-postsync-hook.sh" "${ELASTIC_RELEASE_NAME}" "${ELASTIC_NAMESPACE}"
fi

if [[ "$(rmk --log-level error release -- -l "app=${POSTGRES_RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" == "true" ]]; then
  echo
  echo "Synchronizing ${POSTGRES_RELEASE_NAME}..."
  SKIP_POSTGRES_POSTSYNC_HOOK=true rmk release -- -l "app=${POSTGRES_RELEASE_NAME}-operator" -l "app=${POSTGRES_RELEASE_NAME}" sync
  kubectl -n "${POSTGRES_NAMESPACE}" rollout restart statefulset "${POSTGRES_RELEASE_NAME}-cluster"
  # store current number of replicas of the connection pooler to rollback to the value after all upgrades"
  POSTGRES_CLUSTER_POOLER_REPLICAS="$(kubectl -n "${POSTGRES_NAMESPACE}" get postgresql "${POSTGRES_RELEASE_NAME}-cluster" -o yaml | yq '.spec.connectionPooler.numberOfInstances')"
  kubectl -n "${POSTGRES_NAMESPACE}" scale deployment "${POSTGRES_RELEASE_NAME}-cluster-pooler" --replicas=0
  kubectl -n "${POSTGRES_NAMESPACE}" scale deployment "${POSTGRES_RELEASE_NAME}-cluster-pooler" --replicas="${POSTGRES_CLUSTER_POOLER_REPLICAS}"
  kubectl -n "${POSTGRES_NAMESPACE}" rollout status deployment "${POSTGRES_RELEASE_NAME}-cluster-pooler"
  "$(dirname "${BASH_SOURCE}")/../../postgres-postsync-hook.sh"
fi

echo "Checking all the kafka connectors' tasks are running..."
for KAFKA_CONNECTOR in $(kubectl -n "${KAFKA_NAMESPACE}" get kafkaconnector -o yaml | yq '.items[].metadata.name'); do
  echo "${KAFKA_CONNECTOR}:"
  if [[ "$(kubectl -n "${KAFKA_NAMESPACE}" get kafkaconnector "${KAFKA_CONNECTOR}" -o yaml | yq '.status.connectorStatus.tasks | ([.[] | select(.state == "RUNNING")] | length) == (. | length)')" == "true" ]]; then
    echo "OK."
  else
    echo "Not all the kafka connector's tasks are running. Deleting its pods to force a restart..."
    kubectl -n "${KAFKA_NAMESPACE}" delete pod -l "app.kubernetes.io/instance=${KAFKA_CONNECTOR}"
  fi
done

echo
echo "Synchronizing all releases..."
rmk release sync
