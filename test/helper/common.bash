#!/bin/bash

function __load_bats_helper() {
  load "${REPOSITORY_ROOT}/test/test_helper/bats-support/load"
  load "${REPOSITORY_ROOT}/test/test_helper/bats-assert/load"
}

__load_bats_helper

# -------------------------------------------------------------------

function _run_in_container() {
  run docker exec "${CONTAINER_NAME}" "${@}"
}

function _default_teardown() {
  docker rm -f "${CONTAINER_NAME}"
}

# -------------------------------------------------------------------

# @param ${1} timeout
# @param --fatal-test <command eval string> additional test whose failure aborts immediately
# @param ... test to run
function repeat_until_success_or_timeout {
  local FATAL_FAILURE_TEST_COMMAND

  if [[ "${1}" == "--fatal-test" ]]; then
    FATAL_FAILURE_TEST_COMMAND="${2}"
    shift 2
  fi

  if ! [[ "${1}" =~ ^[0-9]+$ ]]; then
    echo "First parameter for timeout must be an integer, received \"${1}\""
    return 1
  fi

  local TIMEOUT=${1}
  local STARTTIME=${SECONDS}
  shift 1

  until "${@}"
  do
    if [[ -n ${FATAL_FAILURE_TEST_COMMAND} ]] && ! eval "${FATAL_FAILURE_TEST_COMMAND}"; then
      echo "\`${FATAL_FAILURE_TEST_COMMAND}\` failed, early aborting repeat_until_success of \`${*}\`" >&2
      return 1
    fi

    sleep 1

    if [[ $(( SECONDS - STARTTIME )) -gt ${TIMEOUT} ]]; then
      echo "Timed out on command: ${*}" >&2
      return 1
    fi
  done
}

# like repeat_until_success_or_timeout but with wrapping the command to run into `run` for later bats consumption
# @param ${1} timeout
# @param ... test command to run
function run_until_success_or_timeout {
  if ! [[ ${1} =~ ^[0-9]+$ ]]; then
    echo "First parameter for timeout must be an integer, received \"${1}\""
    return 1
  fi

  local TIMEOUT=${1}
  local STARTTIME=${SECONDS}
  shift 1

  until run "${@}" && [[ $status -eq 0 ]]
  do
    sleep 1

    if (( SECONDS - STARTTIME > TIMEOUT )); then
      echo "Timed out on command: ${*}" >&2
      return 1
    fi
  done
}

# @param ${1} timeout
# @param ${2} container name
# @param ... test command for container
function repeat_in_container_until_success_or_timeout() {
  local TIMEOUT="${1}"
  local CONTAINER_NAME="${2}"
  shift 2

  repeat_until_success_or_timeout --fatal-test "container_is_running ${CONTAINER_NAME}" "${TIMEOUT}" docker exec "${CONTAINER_NAME}" "${@}"
}

function container_is_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' "${1}")" == "true" ]]
}

# @param ${1} port
# @param ${2} container name
function wait_for_tcp_port_in_container() {
  repeat_until_success_or_timeout --fatal-test "container_is_running ${2}" "${TEST_TIMEOUT_IN_SECONDS}" docker exec "${2}" /bin/sh -c "nc -z 0.0.0.0 ${1}"
}

# @param ${1} name of the postfix container
function wait_for_smtp_port_in_container() {
  wait_for_tcp_port_in_container 25 "${1}"
}

# @param ${1} name of the postfix container
function wait_for_smtp_port_in_container_to_respond() {
  local COUNT=0
  until [[ $(docker exec "${1}" timeout 10 /bin/sh -c "echo QUIT | nc localhost 25") == *"221 2.0.0 Bye"* ]]; do
    if [[ $COUNT -eq 20 ]]
    then
      echo "Unable to receive a valid response from 'nc localhost 25' within 20 seconds"
      return 1
    fi

    sleep 1
    ((COUNT+=1))
  done
}

# @param ${1} name of the postfix container
function wait_for_amavis_port_in_container() {
  wait_for_tcp_port_in_container 10024 "${1}"
}

# get the private config path for the given container or test file, if no container name was given
function private_config_path() {
  echo "${PWD}/test/duplicate_configs/${1:-$(basename "${BATS_TEST_FILENAME}")}"
}

function container_has_service_running() {
  local CONTAINER_NAME="${1}"
  local SERVICE_NAME="${2}"

  docker exec "${CONTAINER_NAME}" /usr/bin/supervisorctl status "${SERVICE_NAME}" | grep RUNNING >/dev/null
}

function wait_for_service() {
  local CONTAINER_NAME="${1}"
  local SERVICE_NAME="${2}"

  repeat_until_success_or_timeout --fatal-test "container_is_running ${CONTAINER_NAME}" "${TEST_TIMEOUT_IN_SECONDS}" \
    container_has_service_running "${CONTAINER_NAME}" "${SERVICE_NAME}"
}

function wait_for_changes_to_be_detected_in_container() {
  local CONTAINER_NAME="${1}"
  local TIMEOUT=${TEST_TIMEOUT_IN_SECONDS}

  # shellcheck disable=SC2016
  repeat_in_container_until_success_or_timeout "${TIMEOUT}" "${CONTAINER_NAME}" bash -c 'source /usr/local/bin/helpers/index.sh; _obtain_hostname_and_domainname; cmp --silent -- <(_monitored_files_checksums) "${CHKSUM_FILE}" >/dev/null'
}

# Relies on ENV `LOG_LEVEL=debug` or higher
function wait_until_change_detection_event_completes() {
  local CONTAINER_NAME="${1}"
  # Ensure early failure if arg is missing:
  assert_not_equal "${CONTAINER_NAME}" ""

  # Ensure the container is configured with the required `LOG_LEVEL` ENV:
  assert_regex \
    $(docker exec "${CONTAINER_NAME}" env | grep '^LOG_LEVEL=') \
    '=(debug|trace)$'

  local CHANGE_EVENT_START='Change detected'
  local CHANGE_EVENT_END='Completed handling of detected change' # debug log

  function __change_event_status() {
    docker exec "${CONTAINER_NAME}" \
      grep -oE "${CHANGE_EVENT_START}|${CHANGE_EVENT_END}" /var/log/supervisor/changedetector.log \
      | tail -1
  }

  function __is_changedetector_processing() {
    [[ $(__change_event_status) == "${CHANGE_EVENT_START}" ]]
  }

  function __is_changedetector_finished() {
    [[ $(__change_event_status) == "${CHANGE_EVENT_END}" ]]
  }

  if [[ ! $(__is_changedetector_processing) ]]
  then
    # A new change event is expected, wait for it:
    repeat_until_success_or_timeout 60 __is_changedetector_processing
  fi

  # Change event is in progress, wait until it finishes:
  repeat_until_success_or_timeout 60 __is_changedetector_finished

  # NOTE: Although the change event has completed, services like Postfix and Dovecot
  # may still be in the process of restarting.
  # You may still want to wait longer if depending on those to be ready.
}

# An account added to `postfix-accounts.cf` must wait for the `changedetector` service
# to process the update before Dovecot creates the mail account and associated storage dir:
function wait_until_account_maildir_exists() {
  local CONTAINER_NAME=$1
  local MAIL_ACCOUNT=$2

  local LOCAL_PART="${MAIL_ACCOUNT%@*}"
  local DOMAIN_PART="${MAIL_ACCOUNT#*@}"
  local MAIL_ACCOUNT_STORAGE_DIR="/var/mail/${DOMAIN_PART}/${LOCAL_PART}"

  repeat_in_container_until_success_or_timeout 60 "${CONTAINER_NAME}" bash -c "[[ -d ${MAIL_ACCOUNT_STORAGE_DIR} ]]"
}

function add_mail_account_then_wait_until_ready() {
  local CONTAINER_NAME=$1
  local MAIL_ACCOUNT=$2
  # Password is optional (omit when the password is not needed during the test)
  local MAIL_PASS="${3:-password_not_relevant_to_test}"

  run docker exec "${CONTAINER_NAME}" setup email add "${MAIL_ACCOUNT}" "${MAIL_PASS}"
  assert_success

  wait_until_account_maildir_exists "${CONTAINER_NAME}" "${MAIL_ACCOUNT}"
}

function wait_for_empty_mail_queue_in_container() {
  local CONTAINER_NAME="${1}"
  local TIMEOUT=${TEST_TIMEOUT_IN_SECONDS}

  # shellcheck disable=SC2016
  repeat_in_container_until_success_or_timeout "${TIMEOUT}" "${CONTAINER_NAME}" bash -c '[[ $(mailq) == *"Mail queue is empty"* ]]'
}
