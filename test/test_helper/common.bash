#! /bin/bash

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

NAME=${NAME:-mailserver-testing:ci}

# default timeout is 120 seconds
TEST_TIMEOUT_IN_SECONDS=${TEST_TIMEOUT_IN_SECONDS-120}
NUMBER_OF_LOG_LINES=${NUMBER_OF_LOG_LINES-10}

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

# TODO: Should also fail early on "docker logs ${1} | egrep '^[  FATAL  ]'"?
# @param ${1} name of the postfix container
function wait_for_finished_setup_in_container() {
  local STATUS=0
  repeat_until_success_or_timeout --fatal-test "container_is_running ${1}" "${TEST_TIMEOUT_IN_SECONDS}" sh -c "docker logs ${1} | grep 'is up and running'" || STATUS=1

  if [[ ${STATUS} -eq 1 ]]; then
    echo "Last ${NUMBER_OF_LOG_LINES} lines of container \`${1}\`'s log"
    docker logs "${1}" | tail -n "${NUMBER_OF_LOG_LINES}"
  fi

  return ${STATUS}
}

SETUP_FILE_MARKER="${BATS_TMPDIR}/$(basename "${BATS_TEST_FILENAME}").setup_file"

# get the private config path for the given container or test file, if no container name was given
function private_config_path() {
  echo "${PWD}/test/duplicate_configs/${1:-$(basename "${BATS_TEST_FILENAME}")}"
}

# @param ${1} relative source in test/config folder
# @param ${2} (optional) container name, defaults to ${BATS_TEST_FILENAME}
# @return path to the folder where the config is duplicated
function duplicate_config_for_container() {
  local OUTPUT_FOLDER
  OUTPUT_FOLDER=$(private_config_path "${2}")  || return $?

  rm -rf "${OUTPUT_FOLDER:?}/" || return $? # cleanup
  mkdir -p "${OUTPUT_FOLDER}" || return $?
  cp -r "${PWD}/test/config/${1:?}/." "${OUTPUT_FOLDER}" || return $?

  echo "${OUTPUT_FOLDER}"
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

function wait_for_empty_mail_queue_in_container() {
  local CONTAINER_NAME="${1}"
  local TIMEOUT=${TEST_TIMEOUT_IN_SECONDS}

  # shellcheck disable=SC2016
  repeat_in_container_until_success_or_timeout "${TIMEOUT}" "${CONTAINER_NAME}" bash -c '[[ $(mailq) == *"Mail queue is empty"* ]]'
}

# Common defaults appropriate for most tests, override vars in each test when necessary.
# For all tests override in `setup_file()` via an `export` var.
# For individual test override the var via `local` var instead.
#
# For example, if you need an immutable config volume that can't be affected by other tests
# in the file, then use `local TEST_TMP_CONFIG=$(duplicate_config_for_container . "${UNIQUE_ID_HERE}")`
function init_with_defaults() {
  export TEST_NAME TEST_TMP_CONFIG

  # In `setup_file()` the default name to use for the currently tested docker container
  # is `${TEST_NAME}` global defined here. It derives the name from the test filename:
  # `basename` to ignore absolute dir path and file extension, only extract filename.
  TEST_NAME=$(basename "${BATS_TEST_FILENAME}" '.bats')
  # In `setup_file()` creates a single copy of the test config folder to use for an entire test file:
  TEST_TMP_CONFIG=$(duplicate_config_for_container . "${TEST_NAME}")

  # Common complimentary test files, read-only safe to share across containers:
  export TEST_FILES_CONTAINER_PATH='/tmp/docker-mailserver-test'
  export TEST_FILES_VOLUME="${PWD}/test/test-files:${TEST_FILES_CONTAINER_PATH}:ro"

  # The config volume cannot be read-only as some data needs to be written at container startup
  # - two sed failures (unknown lines)
  # - dovecot-quotas.cf (setup-stack.sh:_setup_dovecot_quotas)
  # - postfix-aliases.cf (setup-stack.sh:_setup_postfix_aliases)
  # TODO: Check how many tests need write access. Consider using `docker create` + `docker cp` for easier cleanup.
  export TEST_CONFIG_VOLUME="${TEST_TMP_CONFIG}:/tmp/docker-mailserver"

  # The common default FQDN assigned to the container `--hostname` option:
  export TEST_FQDN='mail.my-domain.com'

  # Default Root CA cert used in TLS tests with `openssl` commands:
  export TEST_CA_CERT="${TEST_FILES_CONTAINER_PATH}/ssl/example.test/with_ca/ecdsa/ca-cert.ecdsa.pem"
}

# Using `create` and `start` instead of only `run` allows to modify
# the container prior to starting it. Otherwise use this combined method.
# NOTE: Forwards all args to the create method at present.
function common_container_setup() {
  common_container_create "$@"
  common_container_start
}

# Common docker setup is centralized here.
#
# `X_EXTRA_ARGS` - Optional: Pass an array by it's variable name as a string, it will
# be used as a reference for appending extra config into the `docker create` below:
#
# NOTE: Using array reference for a single input parameter, as this method is still
# under development while adapting tests to it and requirements it must serve (eg: support base config matrix in CI)
function common_container_create() {
  [[ -n ${1} ]] && local -n X_EXTRA_ARGS=${1}

  run docker create --name "${TEST_NAME}" \
    --hostname "${TEST_FQDN}" \
    --tty \
    --volume "${TEST_FILES_VOLUME}" \
    --volume "${TEST_CONFIG_VOLUME}" \
    "${X_EXTRA_ARGS[@]}" \
    "${NAME}"
  assert_success
}

function common_container_start() {
  run docker start "${TEST_NAME}"
  assert_success

  wait_for_finished_setup_in_container "${TEST_NAME}"
}
