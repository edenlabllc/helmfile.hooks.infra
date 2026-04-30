#!/usr/bin/env bash

set -e

readonly CHART_FULL_NAME="${1}"
readonly CHART_VERSION="${2}"
readonly ADD_SELECTORS="${3}"

SELECTORS='.kind == "CustomResourceDefinition"'

if [[ -n "${ADD_SELECTORS}" ]]; then
  SELECTORS="${SELECTORS} and ${ADD_SELECTORS}"
fi

helm template "${CHART_FULL_NAME}" --version "${CHART_VERSION}" --include-crds | yq "select(${SELECTORS})" | kubectl apply --filename -
