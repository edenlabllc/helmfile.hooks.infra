#!/usr/bin/env bash

set -e

LIMIT="${1:-30}"

echo "Waiting for ${LIMIT} seconds."
sleep "${LIMIT}"
