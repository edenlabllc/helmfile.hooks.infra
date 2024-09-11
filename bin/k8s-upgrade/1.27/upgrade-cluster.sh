#!/usr/bin/env bash

set -e

source "$(dirname "${BASH_SOURCE}")/../upgrade-cluster.sh"

echo "Upgrading K8S cluster iteratively..."
upgrade_cluster "1.24" "v1.24.17-minimal-eksbuild.2" "v1.9.3-eksbuild.7"
upgrade_cluster "1.25" "v1.25.14-minimal-eksbuild.2" "v1.9.3-eksbuild.7"
upgrade_cluster "1.26" "v1.26.9-minimal-eksbuild.2" "v1.9.3-eksbuild.7"
upgrade_cluster "1.27" "v1.27.6-minimal-eksbuild.2" "v1.10.1-eksbuild.4"

echo
echo "Provisioning latest AMI IDs and K8S version..."
rmk cluster provision
