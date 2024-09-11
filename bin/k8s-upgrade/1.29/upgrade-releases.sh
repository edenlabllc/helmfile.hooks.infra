#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

"$(dirname "${BASH_SOURCE}")/upgrade-ebs-csi-snapshot-scheduler.sh"

echo
echo "Synchronizing all releases..."
rmk release sync
