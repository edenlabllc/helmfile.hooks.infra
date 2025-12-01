#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly COMMAND="${3:-start}"
readonly START_PAYLOAD="${4:-{\"source\":\"cluster0\",\"destination\":\"cluster1\"}}"

function cmd() {
    kubectl -n "${NAMESPACE}" exec "deploy/${RELEASE_NAME}" -- "${@}"
}

function check_status() {
    local STATUS="$(cmd curl --max-time 10 --silent http://localhost:27182/api/v1/progress | yq '.success')"

    if [[ "${STATUS}" != "true" ]]; then
      >&2 echo "Mongosync not ready or failed."
      exit 1
    fi
}

case "${COMMAND}" in
  commit)
    check_status
    cmd curl --max-time 10 --silent http://localhost:27182/api/v1/commit -XPOST --data '{}'
    ;;
  pause)
    check_status
    cmd curl --max-time 10 --silent http://localhost:27182/api/v1/pause -XPOST --data '{}'
    ;;
  resume)
    check_status
    cmd curl --max-time 10 --silent http://localhost:27182/api/v1/resume -XPOST --data '{}'
    ;;
  start)
    check_status
    cmd curl --max-time 10 --silent http://localhost:27182/api/v1/start -XPOST --data "${START_PAYLOAD}"
    ;;
  *)
    >&2 echo "Incorrect command name ${COMMAND}; available commands: commit, pause, resume, start."
    exit 1
    ;;
esac
