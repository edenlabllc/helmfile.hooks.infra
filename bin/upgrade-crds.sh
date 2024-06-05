#!/usr/bin/env bash

set -e

CHART_FULL_NAME="${1}"
CHART_VERSION="${2}"

helm template "${CHART_FULL_NAME}" --version "${CHART_VERSION}" --include-crds | yq 'select(.kind == "CustomResourceDefinition")' | kubectl apply -f -
