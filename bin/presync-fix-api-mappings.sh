#!/usr/bin/env bash

set -e

NAMESPACE="${1}"
RELEASE_NAME="${2}"

PLUGIN_NAME="mapkubeapis"

if ! helm plugin list | grep -q "${PLUGIN_NAME}"; then
  echo "Helm plugin ${PLUGIN_NAME} not installed."
  echo "Skipped."
elif [[ -z "$(helm -n "${NAMESPACE}" list --deployed --output yaml | yq -r '.[] | select(.name == "'"${RELEASE_NAME}"'") | .name')" ]]; then
  echo "Release not deployed. No need to check the API mappings."
  echo "Skipped."
else
  echo helm "${PLUGIN_NAME}" --namespace "${NAMESPACE}" "${RELEASE_NAME}"
fi
