#!/usr/bin/env bash

set -e

# Cluster API settings
export EXP_AKS=true
export EXP_MACHINE_POOL=true
export EXP_CLUSTER_RESOURCE_SET=false

clusterctl init --infrastructure azure --wait-providers
