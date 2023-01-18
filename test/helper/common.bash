#!/bin/bash

function __load_bats_helper() {
  load "${REPOSITORY_ROOT}/test/test_helper/bats-support/load"
  load "${REPOSITORY_ROOT}/test/test_helper/bats-assert/load"
}

__load_bats_helper

# -------------------------------------------------------------------

# like _run_in_container_explicit but infers ${1} by using the ENV CONTAINER_NAME
# WARNING: Careful using this with _until_success_or_timeout methods,
# which can be misleading in the success of `run`, not the command given to `run`.
function _run_in_container() {
  run docker exec "${CONTAINER_NAME}" "${@}"
}

# @param ${1} container name [REQUIRED]
# @param ... command to execute
function _run_in_container_explicit() {
  local CONTAINER_NAME=${1:?Container name must be given when using explicit}
  shift 1
  run docker exec "${CONTAINER_NAME}" "${@}"
}

function _default_teardown() {
  docker rm -f "${CONTAINER_NAME}"
}

function _reload_postfix() {
  local CONTAINER_NAME=${1:-${CONTAINER_NAME}}

  # Reloading Postfix config after modifying it in <2 sec will cause Postfix to delay, workaround that:
  docker exec "${CONTAINER_NAME}" touch -d '2 seconds ago' /etc/postfix/main.cf
  docker exec "${CONTAINER_NAME}" postfix reload
}

# -------------------------------------------------------------------

# @param ${1} target container name [IF UNSET: ${CONTAINER_NAME}]
function get_container_ip() {
  local TARGET_CONTAINER_NAME=${1:-${CONTAINER_NAME}}
  docker inspect --format '{{ .NetworkSettings.IPAddress }}' "${TARGET_CONTAINER_NAME}"
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

# NOTE: Relies on ENV `LOG_LEVEL=debug` or higher
function _wait_until_expected_count_is_matched() {
  function __get_count() {
    # NOTE: `|| true` required due to `set -e` usage:
    # https://github.com/docker-mailserver/docker-mailserver/pull/2997#discussion_r1070583876
    docker exec "${CONTAINER_NAME}" grep --count "${MATCH_CONTENT}" "${MATCH_IN_LOG}" || true
  }

  # WARNING: Keep in mind it is a '>=' comparison.
  # If you provide an explict count to match, ensure it is not too low to cause a false-positive.
  function __has_expected_count() {
    [[ $(__get_count) -ge "${EXPECTED_COUNT}" ]]
  }

  local CONTAINER_NAME=${1}
  local EXPECTED_COUNT=${2}

  # Ensure early failure if arg is missing:
  assert_not_equal "${CONTAINER_NAME}" ''

  # Ensure the container is configured with the required `LOG_LEVEL` ENV:
  assert_regex \
    $(docker exec "${CONTAINER_NAME}" env | grep '^LOG_LEVEL=') \
    '=(debug|trace)$'

  # Default behaviour is to wait until one new match is found (eg: incremented),
  # unless explicitly set (useful for waiting on a min count to be reached):
  if [[ -z $EXPECTED_COUNT ]]
  then
    # +1 of starting count:
    EXPECTED_COUNT=$(( $(__get_count) + 1 ))
  fi

  repeat_until_success_or_timeout 20 __has_expected_count
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

# `lines` is a special BATS variable updated via `run`:
function _should_output_number_of_lines() {
  assert_equal "${#lines[@]}" $1
}
