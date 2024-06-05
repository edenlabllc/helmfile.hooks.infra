#!/usr/bin/env bash

set -e

# Upgrading kafka operator explicitly for old versions of deps/hooks.
# New versions of deps/hooks should use the "upgrade-crds.sh" hook for upgrading chart CRDs automatically,
# e.g. for operators like kafka-operator
echo
"$(dirname "${BASH_SOURCE}")/upgrade-kafka-operator.sh"

echo
"$(dirname "${BASH_SOURCE}")/upgrade-postgres-operator.sh"

echo
"$(dirname "${BASH_SOURCE}")/upgrade-loki-stack.sh"

echo
"$(dirname "${BASH_SOURCE}")/upgrade-linkerd-planes.sh"
