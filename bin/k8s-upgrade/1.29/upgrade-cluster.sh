#!/usr/bin/env bash

set -e

source "$(dirname "${BASH_SOURCE}")/../upgrade-cluster.sh"

echo "Upgrading K8S cluster iteratively..."
upgrade_cluster "1.28" "v1.28.12-eksbuild.2" "v1.10.1-eksbuild.13"
upgrade_cluster "1.29" "v1.29.0-minimal-eksbuild.1" "v1.11.1-eksbuild.4"

echo
echo "Provisioning latest AMI IDs and K8S version..."
rmk cluster provision
