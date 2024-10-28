#!/usr/bin/env bash

set -e

# Cluster API settings
export EXP_MACHINE_POOL="true"
# https://cluster-api-aws.sigs.k8s.io/topics/eks/enabling
export CAPA_EKS_IAM="true"
export CAPA_EKS_ADD_ROLES="true"

clusterctl init --infrastructure aws --wait-providers
