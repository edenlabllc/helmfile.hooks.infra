#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

echo "Initializing cluster configuration..."
rmk update
rmk config init
rmk cluster switch -f

echo
"$(dirname "${BASH_SOURCE}")/upgrade-releases.sh"

echo
"$(dirname "${BASH_SOURCE}")/upgrade-cluster.sh"

echo
"$(dirname "${BASH_SOURCE}")/upgrade-nodes.sh"

echo
"$(dirname "${BASH_SOURCE}")/run-tests.sh"
