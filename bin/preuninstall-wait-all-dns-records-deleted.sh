#!/usr/bin/env bash

set -e

readonly LIMIT="${1:-30}"

echo "Waiting for ${LIMIT} seconds..."
sleep "${LIMIT}"
