#!/usr/bin/env bash

set -e

readonly NAMESPACE="${1}"
readonly RELEASE_NAME="${2}"
readonly USERNAME="${3}"
readonly PASSWORD="${4}"
readonly DATABASE="${5}"

readonly CONTAINER_NAME="mongodb"
readonly USER_PERMISSIONS="readWrite"

function mongodb_exec() {
  kubectl --namespace "${NAMESPACE}" exec --stdin "${RELEASE_NAME}-0" --container "${CONTAINER_NAME}" -- bash -c "${1}"
}

function check_user() {
  mongodb_exec 'mongo -u root -p ${MONGODB_ROOT_PASSWORD} --quiet --eval \
    "result=db.getSiblingDB(\"'"${DATABASE}"'\").getUser(\"'"${USERNAME}"'\"); \
    result.userId=result.userId.toString(); \
    print(JSON.stringify(result))"'
}

function create_user() {
  mongodb_exec 'mongo -u root -p ${MONGODB_ROOT_PASSWORD} --quiet --eval \
    "db.getSiblingDB(\"'"${DATABASE}"'\").createUser({ user: \"'"${USERNAME}"'\", \
    pwd: \"'"${PASSWORD}"'\", roles: [{role: \"'"${USER_PERMISSIONS}"'\", db: \"'"${DATABASE}"'\"}] })"'
}

set +e
CHECK_USER="$(check_user 2> /dev/null)"
RESULT="$(echo "${CHECK_USER}" | yq --unwrapScalar '.roles[].role' 2> /dev/null)"
set -e

MESSAGE="MongoDB user \"${USERNAME}\" with permissions \"${USER_PERMISSIONS}\" to database \"${DATABASE}\""
if [[ "${RESULT}" != "${USER_PERMISSIONS}" ]]; then
  echo "Creating ${MESSAGE}..."
  create_user
  echo "Done."
else
  echo "${MESSAGE} already exists."
fi
