#!/usr/bin/env bash

set -e

export PATH="${HOME}/.local/bin:${PATH}"

readonly RELEASE_NAME="postgres-operator"

readonly CHART_NAME="postgres-operator"
readonly CHART_VERSION="v1.10.1"

readonly CRDS=("operatorconfigurations" "postgresqls" "postgresteams")

echo "Checking whether ${RELEASE_NAME} release installed..."
if [[ "$(rmk --log-level error release -- -l "app=${RELEASE_NAME}" --log-level error list --output json | yq '.[0].installed')" != "true" ]]; then
  echo "Skipped."
  exit
fi

echo "Upgrading CRDs for chart ${CHART_NAME} to version ${CHART_VERSION}..."

for CRD in "${CRDS[@]}"; do
  kubectl apply --wait=true -f "https://raw.githubusercontent.com/zalando/${CHART_NAME}/${CHART_VERSION}/charts/${CHART_NAME}/crds/${CRD}.yaml"
done
