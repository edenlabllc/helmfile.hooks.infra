#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

readonly RELEASE_NAME="kafka-operator"

readonly CHART_REPO="core-charts"
readonly CHART_NAME="strimzi-kafka-operator"
readonly CHART_VERSION="0.37.0" # kodjin v3.8.3 / deps v2.7.4
#readonly CHART_VERSION="0.39.0" # kodjin v4.1.0+ / deps v2.10.0+

echo "Checking whether ${RELEASE_NAME} release installed..."
if [[ "$(rmk --log-level error release -- -l "app=${RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" != "true" ]]; then
  echo "Skipped."
  exit
fi

echo "Upgrading CRDs for chart ${CHART_NAME} to version ${CHART_VERSION}..."
"$(dirname "${BASH_SOURCE}")/../../upgrade-crds.sh" "${CHART_REPO}/${CHART_NAME}" "${CHART_VERSION}"
