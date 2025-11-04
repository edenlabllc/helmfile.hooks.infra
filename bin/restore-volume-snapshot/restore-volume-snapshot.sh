#!/usr/bin/env bash

### RESTORE VOLUME SNAPSHOT script ###
# Requirements:
#   - yq >= 4.28.*
#   - Initialized tenant repo via RMK.
#   - Previously installed and running ebs-csi-snapshot-scheduler for the required release.

set -e

readonly COMMAND="${1}"
readonly RELEASE_NAME="${2}"
readonly SNAPSHOT_DATE="${3}"
readonly OLD_IFS="${IFS}"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="${SCRIPT_DIR}"

# permanent files
readonly INVENTORY_FILE="${WORK_DIR}/inventory.yaml"
# temporary files
readonly PVC_DATA_FILE="${WORK_DIR}/.pvc-data.${RELEASE_NAME}.yaml"
readonly PVC_PREPARE_FILE="${WORK_DIR}/.pvc-prepare.${RELEASE_NAME}.yaml"
readonly PVC_RESTORE_FILE="${WORK_DIR}/.pvc-restore.${RELEASE_NAME}.yaml"

function clear_work_dir() {
  rm -f "${WORK_DIR}"/.pvc-*.yaml
}

function create_work_dir() {
  mkdir -p "${WORK_DIR}"
}

###
# Handling exceptions.
###
function check_release_name() {
  if [[ -z "${RELEASE_NAME}" ]]; then
    >&2 echo "ERROR: release name not specified."
    return 1
  fi
}

function check_snapshot_date() {
  if [[ -z "${SNAPSHOT_DATE}" ]]; then
    >&2 echo "ERROR: snapshot date not specified."
    return 1
  fi
}

function check_inventory() {
  if [[ ! -f "${INVENTORY_FILE}"  ]]; then
    >&2 echo "ERROR: ${INVENTORY_FILE} - not exist."
    return 1
  fi

  COUNT_RELEASES="$(yq '.releases | length' "${INVENTORY_FILE}")"
  if ((COUNT_RELEASES == 0)); then
    >&2 echo "ERROR: the inventory file does not contain the listed releases."
    return 1
  fi
}

function check_inventory_release_resource() {
  check_inventory
  COUNT_RESOURCES="$(yq '.releases.'"${RELEASE_NAME}"' | length' "${INVENTORY_FILE}")"
  if ((COUNT_RESOURCES == 0)); then
    >&2 echo "ERROR: the inventory file does not contain the listed resources for selected release ${RELEASE_NAME}."
    return 1
  fi
}

###
# Reading and validating an inventory file.
###
function validate_inventory_release_options() {
  KEY_OPTION="$(yq '.releases.'"${RELEASE_NAME}"'.'"${1}"' | has("'"${2}"'")' "${INVENTORY_FILE}")"
  LEN_VALUE_OPTION="$(yq '.releases.'"${RELEASE_NAME}"'.'"${1}"'.'"${2}"'| length' "${INVENTORY_FILE}")"
  if [[ "${KEY_OPTION}" == "false" ]] || ((LEN_VALUE_OPTION == 0)); then
    >&2 echo "ERROR: the inventory file does not contain the option ${2} in resource ${1} for selected release ${RELEASE_NAME}."
    return 1
  fi
}

function get_inventory_release_options() {
  check_inventory_release_resource
  if [[ "$(yq '.releases.'"${RELEASE_NAME}"' | has("'"${1}"'")' "${INVENTORY_FILE}")" == "true" ]]; then
    validate_inventory_release_options "${1}" resourceType
    INVENTORY_RELEASE_RESOURCE_TYPE="$(yq '.releases.'"${RELEASE_NAME}"'.'"${1}"'.resourceType' "${INVENTORY_FILE}")"
    validate_inventory_release_options "${1}" namespace
    INVENTORY_RELEASE_NAMESPACE="$(yq '.releases.'"${RELEASE_NAME}"'.'"${1}"'.namespace' "${INVENTORY_FILE}")"
    validate_inventory_release_options "${1}" replicas
    INVENTORY_RELEASE_REPLICAS_COUNT="$(yq '.releases.'"${RELEASE_NAME}"'.'"${1}"'.replicas' "${INVENTORY_FILE}")"
    validate_inventory_release_options "${1}" name
    INVENTORY_RELEASE_RESOURCE_NAME="$(yq '.releases.'"${RELEASE_NAME}"'.'"${1}"'.name' "${INVENTORY_FILE}")"

    INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS=""
    if [[ "$(yq '.releases.'"${RELEASE_NAME}"'.'"${1}"' | has("claimSelector")' "${INVENTORY_FILE}")" != "true" ]]; then
      return 0
    fi

    validate_inventory_release_options "${1}.claimSelector" matchLabels

    LABELS_COUNT=0
    IFS=$'\n'
    for ITEM in $(yq -r '.releases.'"${RELEASE_NAME}"'.'"${1}"'.claimSelector.matchLabels' "${INVENTORY_FILE}"); do
      if ((LABELS_COUNT == 0)); then
        INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS="${INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS}${ITEM/: /=}"
      else
        INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS="${INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS},${ITEM/: /=}"
      fi

      ((++LABELS_COUNT))
    done

    INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS="-l ${INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS}"
  else
    false
  fi
}

###
# Processing snapshots and PVСs for the selected release.
###
function get_existing_pvcs() {
  clear_work_dir
  eval kubectl get persistentvolumeclaim --namespace "${INVENTORY_RELEASE_NAMESPACE}" --output yaml "${INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS}" | yq '. |
  del(.items[].status,
    .items[].spec.volumeMode,
    .items[].spec.volumeName,
    .items[].spec.dataSource,
    .items[].metadata.annotations."kubectl.kubernetes.io/last-applied-configuration",
    .items[].metadata.finalizers,
    .items[].metadata.creationTimestamp,
    .items[].metadata.uid,
    .items[].metadata.resourceVersion) | .items' > "${PVC_DATA_FILE}"
}

function add_separators() {
  if ((${1} <= PVC_LENGTH-1)); then
    echo "---" >> "${2}"
  fi
}

function get_current_pvc_data() {
  if [[ ! -f "${PVC_DATA_FILE}"  ]]; then
    >&2 echo "ERROR: ${PVC_DATA_FILE} - not created."
    return 1
  fi

  readonly PVC_DATA="$(yq '.' "${PVC_DATA_FILE}")"
  readonly PVC_LENGTH="$(yq 'length' "${PVC_DATA_FILE}")"
}

function prepare_pvcs() {
  COUNT=0
  touch "${PVC_PREPARE_FILE}"
  while [ "${COUNT}" -lt "${PVC_LENGTH}" ]; do
    PVC_NAME="$(echo "${PVC_DATA}" | yq '.['"${COUNT}"'].metadata.name')"
    echo "Found PVC: ${PVC_NAME}"
    if (kubectl get volumesnapshot "${PVC_NAME}-${RELEASE_NAME}-ebs-csi-snapshot-${SNAPSHOT_DATE}" --namespace "${INVENTORY_RELEASE_NAMESPACE}" 1> /dev/null); then
      echo "${PVC_DATA}" | yq '.['"${COUNT}"'] | .spec +=
        {"dataSource":
          {"apiGroup":"snapshot.storage.k8s.io",
            "kind":"VolumeSnapshot",
            "name":"'"${PVC_NAME}"'-'"${RELEASE_NAME}"'-ebs-csi-snapshot-'"${SNAPSHOT_DATE}"'"}}' >> "${PVC_PREPARE_FILE}"
    fi

    ((++COUNT))
    add_separators "${COUNT}" "${PVC_PREPARE_FILE}"
  done
}

function restore_pvcs() {
  if [[ ! -f "${PVC_PREPARE_FILE}"  ]]; then
    >&2 echo "ERROR: ${PVC_PREPARE_FILE} - not created."
    return 1
  fi

  COUNT=0
  touch "${PVC_RESTORE_FILE}"
  while [ "${COUNT}" -lt "${PVC_LENGTH}" ]; do
    PVC_NAME="$(echo "${PVC_DATA}" | yq '.['"${COUNT}"'].metadata.name')"
    PV_NAME="$(kubectl get persistentvolume --output yaml | yq '.items[] | select(.spec.claimRef.name == "'"${PVC_NAME}"'" and .status.phase == "Pending") | .metadata.name')"
    echo "Found PV: ${PV_NAME} for PVC: ${PVC_NAME}"
    if [[ -n "${PV_NAME}" ]]; then
      yq 'select(document_index == '"${COUNT}"') | .spec +=
        {"volumeMode": "Filesystem", "volumeName": "'"${PV_NAME}"'"}' "${PVC_PREPARE_FILE}" >> "${PVC_RESTORE_FILE}"
    fi

    ((++COUNT))
    add_separators "${COUNT}" "${PVC_RESTORE_FILE}"
  done
}

###
# Downscale or upscale resources for the selected release.
###
function get_available_replicas() {
  AVAILABLE_REPLICAS="$(kubectl get --namespace "${INVENTORY_RELEASE_NAMESPACE}" "${INVENTORY_RELEASE_RESOURCE_TYPE}" \
  "${INVENTORY_RELEASE_RESOURCE_NAME}" --output yaml | yq '.status.availableReplicas')"
}

function scale_release_resources() {
  RESOURCES=("${1}")
  COUNT=0
  IFS="${OLD_IFS}"

  for RESOURCE in ${RESOURCES[*]}; do
    if get_inventory_release_options "${RESOURCE}"; then
      if [[ "${3}" == "upscale" ]]; then
        COUNT="${INVENTORY_RELEASE_REPLICAS_COUNT}"
      fi

      get_available_replicas
      echo "Inventory ${INVENTORY_RELEASE_RESOURCE_NAME} replicas count: ${INVENTORY_RELEASE_REPLICAS_COUNT}"
      echo "Available ${INVENTORY_RELEASE_RESOURCE_NAME} replicas count: ${AVAILABLE_REPLICAS}"
      if (("${2}")); then
        kubectl --namespace "${INVENTORY_RELEASE_NAMESPACE}" scale "${INVENTORY_RELEASE_RESOURCE_TYPE}" "${INVENTORY_RELEASE_RESOURCE_NAME}" --replicas="${COUNT}"
        echo -ne "Wait ${3} ${RELEASE_NAME} release for resource: ${INVENTORY_RELEASE_RESOURCE_TYPE}, name: ${INVENTORY_RELEASE_RESOURCE_NAME}"
        while (("${4}")); do
          get_available_replicas
          echo -ne " . "
          sleep 1
        done

        echo -en "\n"
        echo "${5}"
      fi
    fi
  done
}

function downscale_release_resources() {
  #  Required parameters
  #  1 - resources list
  #  2 - first check of the process start condition
  #  3 - process
  #  4 - condition to wait for execution
  #  5 - final message
  scale_release_resources \
    "operator cluster" \
    "INVENTORY_RELEASE_REPLICAS_COUNT == AVAILABLE_REPLICAS" \
    "downscale" \
    "AVAILABLE_REPLICAS > 0" \
    "Release: ${RELEASE_NAME}, reduced the number of replicas to 0."
}

function upscale_release_resources() {
  #  Required parameters
  #  1 - resources list
  #  2 - first check of the process start condition
  #  3 - process
  #  4 - condition to wait for execution
  #  5 - final message
  scale_release_resources \
    "operator cluster" \
    "AVAILABLE_REPLICAS == 0" \
    "upscale" \
    "AVAILABLE_REPLICAS < INVENTORY_RELEASE_REPLICAS_COUNT" \
    "Release: ${RELEASE_NAME}, upscaled the number of replicas according to inventory file."
}

###
# Calling main commands.
###
case "${COMMAND}" in
help|h|-h|--help)
  HELP='RESTORE VOLUME SNAPSHOT script - automation of restore snapshots process for selected stateful Helm release.

COMMANDS:
  list | l - listing all available Helm releases defined in inventory file.
  list-snapshots | ls - listing all snapshots for the selected Helm release.
    args:
      1. - release name.
  prepare | p - preparation of an intermediate PVCs manifest from the specified snapshot time and Helm release.
    args:
      1. - release name.
      2. - snapshot date by format [202210130000] (<year><month><day><time> - without spaces).
  restore | r - restore pvc from snapshot and run Helm release.
    args:
      1. - release name.'
  echo "${HELP}"
  ;;
list|l)
  check_inventory
  
  yq '.releases | keys | .[]' "${INVENTORY_FILE}"
  ;;
list-snapshots|ls)
  check_release_name
  get_inventory_release_options cluster

  VOLUME_SNAPSHOT_NAME=""
  VOLUME_SNAPSHOT_COUNT=0
  for PVC_NAME in $(eval kubectl get persistentvolumeclaim --namespace "${INVENTORY_RELEASE_NAMESPACE}" --output yaml "${INVENTORY_RELEASE_CLAIM_SELECTOR_MATCH_LABELS}" | yq '.items[].metadata.name'); do
    if ((VOLUME_SNAPSHOT_COUNT == 0)); then
      VOLUME_SNAPSHOT_NAME="${VOLUME_SNAPSHOT_NAME}^${PVC_NAME}-${RELEASE_NAME}-ebs-csi-snapshot-.+$"
    else
      VOLUME_SNAPSHOT_NAME="${VOLUME_SNAPSHOT_NAME}|^${PVC_NAME}-${RELEASE_NAME}-ebs-csi-snapshot-.+$"
    fi

    ((++VOLUME_SNAPSHOT_COUNT))
  done

  kubectl get volumesnapshot --namespace "${INVENTORY_RELEASE_NAMESPACE}" --output yaml | yq '.items[].metadata.name | select(test("'"${VOLUME_SNAPSHOT_NAME}"'"))'
  ;;
prepare|p)
  check_release_name
  check_snapshot_date
  get_inventory_release_options cluster
  get_existing_pvcs
  get_current_pvc_data
  prepare_pvcs
  downscale_release_resources
  
  for ITEM in $(echo "${PVC_DATA}" | yq '.[].metadata.name'); do
    kubectl delete pvc "${ITEM}" --namespace "${INVENTORY_RELEASE_NAMESPACE}"
  done
  
  kubectl apply -f "${PVC_PREPARE_FILE}"
  ;;
restore|r)
  rm -f "${PVC_RESTORE_FILE}"

  check_release_name
  get_current_pvc_data
  restore_pvcs
  
  kubectl apply -f "${PVC_RESTORE_FILE}"
  
  upscale_release_resources
esac
