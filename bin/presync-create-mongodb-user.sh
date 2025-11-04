#!/usr/bin/env bash

set -e

MONGODB_NAMESPACE=${1}
MONGODB_RELEASE_NAME=${2}
MONGODB_CONTAINER_NAME=mongodb

MONGODB_USERNAME=${3}
MONGODB_PASSWORD=${4}
MONGODB_DATABASE=${5}

MONGODB_USER_PERMISSIONS=readWrite

function mongodb_exec() {
  kubectl --namespace "${MONGODB_NAMESPACE}" exec --stdin "${MONGODB_RELEASE_NAME}-0" --container "${MONGODB_CONTAINER_NAME}" -- bash -c "${1}"
}

function check_user() {
  mongodb_exec 'mongo -u root -p ${MONGODB_ROOT_PASSWORD} --quiet --eval \
    "result=db.getSiblingDB(\"'"${MONGODB_DATABASE}"'\").getUser(\"'"${MONGODB_USERNAME}"'\"); \
    result.userId=result.userId.toString(); \
    print(JSON.stringify(result))"'
}

function create_user() {
  mongodb_exec 'mongo -u root -p ${MONGODB_ROOT_PASSWORD} --quiet --eval \
    "db.getSiblingDB(\"'"${MONGODB_DATABASE}"'\").createUser({ user: \"'"${MONGODB_USERNAME}"'\", \
    pwd: \"'"${MONGODB_PASSWORD}"'\", roles: [{role: \"'"${MONGODB_USER_PERMISSIONS}"'\", db: \"'"${MONGODB_DATABASE}"'\"}] })"'
}

set +e
CHECK_USER=$(check_user 2> /dev/null)
RESULT=$(echo "${CHECK_USER}" | yq '.roles[].role' -r 2> /dev/null)
set -e

MESSAGE="MongoDB user \"${MONGODB_USERNAME}\" with permissions \"${MONGODB_USER_PERMISSIONS}\" to database \"${MONGODB_DATABASE}\""
if [[ "${RESULT}" != "${MONGODB_USER_PERMISSIONS}" ]]; then
  echo "Creating ${MESSAGE}..."
  create_user
  echo "Done."
else
  echo "${MESSAGE} already exists."
fi
