#!/usr/bin/env bash

set -e

NAME_SERVER="${1}"
DOMAIN="${2}"
LIMIT="${3:-120}"

COUNT=1

while true; do
  RESULT=$(dig +short "${NAME_SERVER}" "${DOMAIN}")
  if [[ ${RESULT} == "" && "${COUNT}" -le "${LIMIT}" ]]; then
    sleep 1
    (( ++COUNT ))
  elif [[ "${COUNT}" -gt "${LIMIT}" ]]; then
    >&2 echo "Limit exceeded."
    exit 1
  else
    echo "${RESULT}"
    break
  fi
done
