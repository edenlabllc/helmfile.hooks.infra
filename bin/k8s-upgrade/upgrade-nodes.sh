#!/usr/bin/env bash

set -e

# optional argument
# e.g. postgres|minio
# find all possible node group names in etc/**/worker-groups.auto.tfvars of a tenant repository
NODE_GROUP_NAME="${1}"

export PATH="${HOME}/.local/bin:${PATH}"

# disable client-side pager
export AWS_PAGER=
export AWS_PROFILE="$(rmk --log-level error config view | yq '.aws.profile')"
export AWS_CONFIG_FILE="${HOME}/.aws/config_${AWS_PROFILE}"
export AWS_SHARED_CREDENTIALS_FILE="${HOME}/.aws/credentials_${AWS_PROFILE}"

readonly NAME="$(rmk --log-level error config view | yq '.name')"
CLUSTER_NAME="$(rmk --log-level error config view | yq '.exported-vars.env.CLUSTER_NAME')"
if [[ "${CLUSTER_NAME}" == "null" ]]; then
  CLUSTER_NAME="${NAME}-eks"
fi

NODE_GROUP_FILTER=""
if [[ -n "${NODE_GROUP_NAME}" ]]; then
  NODE_GROUP_FILTER="Name=tag-value,Values=${CLUSTER_NAME}-${NODE_GROUP_NAME}-eks_asg"
fi

ASG_TAGS=($(aws autoscaling describe-auto-scaling-groups \
    --filters "Name=tag-key,Values=kubernetes.io/cluster/${CLUSTER_NAME}" ${NODE_GROUP_FILTER} \
    --output yaml | yq '.AutoScalingGroups[].Tags[] | select(.Key == "Name") | .Value'))
ASG_NAMES=()

if [[ ${#ASG_TAGS[@]} -eq 0 ]]; then
  >&2 echo "ERROR: No autoscaling group found."
  exit 1
fi

echo "Rolling-updating nodes..."

for ASG_TAG in ${ASG_TAGS[@]}; do
  ASG_NAME="$(aws autoscaling describe-auto-scaling-groups \
    --filters "Name=tag-value,Values=${ASG_TAG}" \
    --query 'AutoScalingGroups[0].AutoScalingGroupName' \
    --output text
  )"
  ASG_NAMES+=("${ASG_NAME}")
  # nodes with STS/PVC/PV need up to 10 minutes or more to warm up/check health and mount devices
  ASG_UPDATE_TIMEOUT_SECONDS=600

  # remove prefix and suffix from ASG tag to get node group name
  NODE_GROUP_NAME="${ASG_TAG#${CLUSTER_NAME}-}"
  NODE_GROUP_NAME="${NODE_GROUP_NAME%-eks_asg}"
  IS_NODE_GROUP_STATEFUL="true"
  PVC_LABELS="";
  case "${NODE_GROUP_NAME}" in
    "clickhouse") PVC_LABELS="clickhouse.altinity.com/chi=clickhouse" ;;
    "elt-postgres") PVC_LABELS="cluster-name=elt-postgres-cluster" ;;
    "es") PVC_LABELS="elasticsearch.k8s.elastic.co/cluster-name=elastic" ;;
    "es-jaeger") PVC_LABELS="elasticsearch.k8s.elastic.co/cluster-name=elastic-jaeger" ;;
    "fhir-postgres") PVC_LABELS="cluster-name=fhir-postgres-cluster" ;;
    "kafka") PVC_LABELS="app.kubernetes.io/instance=kafka" ;;
    "loki-stack") PVC_LABELS="release=loki-stack" ;;
    "minio") PVC_LABELS="release=minio" ;;
    "mongodb") PVC_LABELS="app.kubernetes.io/instance=mongodb" ;;
    "postgres") PVC_LABELS="cluster-name=postgres-cluster" ;;
    "redis") PVC_LABELS="app.kubernetes.io/instance=redis" ;;
    *) IS_NODE_GROUP_STATEFUL="false"; ASG_UPDATE_TIMEOUT_SECONDS=60 ;;
  esac

  echo
  echo "Node group name: ${NODE_GROUP_NAME}"
  echo "Stateful: ${IS_NODE_GROUP_STATEFUL}"
  echo "ASG tag: ${ASG_TAG}"
  echo "ASG name: ${ASG_NAME}"
  echo "ASG update timeout: ${ASG_UPDATE_TIMEOUT_SECONDS}s"

  if [[ "${IS_NODE_GROUP_STATEFUL}" == "true" && "${PVC_LABELS}" != "" ]]; then
    echo "PVC labels: ${PVC_LABELS}"

    PV_NAMES="$(kubectl get pvc --all-namespaces -l "${PVC_LABELS}" -o yaml | yq '.items[].spec.volumeName')"
    echo "PV names: ${PV_NAMES}"

    # adding pv-dummy to return list of items even for cases when we have only 1 PV found
    ASG_AZS="$(kubectl get pv pv-dummy ${PV_NAMES} --ignore-not-found -o yaml | yq '.items[].spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]' | sort | uniq)"
    echo "ASG availability zones: ${ASG_AZS}"

    ASG_SUBNETS=""
    for ASG_AZ in ${ASG_AZS}; do
      echo "Getting private subnet for ${ASG_AZ}..."
      ASG_SUBNET="$(aws ec2 describe-subnets --filters "Name=tag-value,Values=${NAME}-vpc-private-${ASG_AZ}" --output yaml | yq '.Subnets[0].SubnetId')"
      echo "Subnet ID: ${ASG_SUBNET}"
      ASG_SUBNETS="${ASG_SUBNETS} ${ASG_SUBNET}"
    done
    echo "ASG subnets:${ASG_SUBNETS}"

    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "${ASG_NAME}" \
      --availability-zones ${ASG_AZS} \
      --vpc-zone-identifier "${ASG_SUBNETS// /,}" \
      --default-cooldown ${ASG_UPDATE_TIMEOUT_SECONDS} \
      --default-instance-warmup ${ASG_UPDATE_TIMEOUT_SECONDS} \
      --health-check-grace-period ${ASG_UPDATE_TIMEOUT_SECONDS} || true
  else
    echo "No ASG AZ update needed for stateless node group."
  fi

  # rolling-update node group OR skip in case it is being updated already
  echo "Starting instance refresh..."
  aws autoscaling start-instance-refresh --auto-scaling-group-name "${ASG_NAME}" || true
done

echo
echo "Checking instance refresh status.."
while true; do
  IN_PROGRESS_ASG_COUNT="${#ASG_NAMES[@]}"
  for ASG_NAME in ${ASG_NAMES[@]}; do
    ASG_INSTANCE_REFRESH="$(aws autoscaling describe-instance-refreshes \
      --auto-scaling-group-name "${ASG_NAME}" \
      --max-records 1 \
      --output yaml | yq '.InstanceRefreshes[0] | select(.Status != "Successful" and .Status != "Cancelled") | .AutoScalingGroupName')"

    if [[ -n "${ASG_INSTANCE_REFRESH}" && "${ASG_INSTANCE_REFRESH}" != "null" ]]; then
      echo "ASG ${ASG_NAME} in progress..."
    else
      ((IN_PROGRESS_ASG_COUNT--))
    fi
  done

  if [[ "${IN_PROGRESS_ASG_COUNT}" -gt 0 ]]; then
    sleep 10
  else
    break
  fi
done
echo "Done."

echo
echo "Fixing pods with a missing linkerd sidecar after the instance refresh..."
PODS_WITH_MISSING_LINKERD_SIDECAR="$(kubectl get pods --all-namespaces -l "!linkerd.io/control-plane-ns" -o yaml | yq '.items[].metadata | select(.annotations["linkerd.io/inject"] == "enabled") | (.namespace + " " + .name)')"
# iterate over lines ignoring spaces
while IFS= read -r NAMESPACE_WITH_POD_NAME; do
  if [[ -z "${NAMESPACE_WITH_POD_NAME}" ]]; then
    # no corrupted pod found
    break
  fi
  kubectl delete pod --wait=true -n ${NAMESPACE_WITH_POD_NAME}
done <<< "${PODS_WITH_MISSING_LINKERD_SIDECAR}"
echo "Done."
