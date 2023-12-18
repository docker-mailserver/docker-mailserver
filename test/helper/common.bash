#!/bin/bash

# ? ABOUT: Functions defined here aid with common functionality during tests.

# ! ATTENTION: Functions prefixed with `__` are intended for internal use within this file only, not in tests.

# ! -------------------------------------------------------------------
# ? >> Miscellaneous initialization functionality

# shellcheck disable=SC2155

# Load additional BATS libraries for more functionality.
#
# ## Note
#
# This function is internal and should not be used in tests.
function __load_bats_helper() {
  load "${REPOSITORY_ROOT}/test/test_helper/bats-support/load"
  load "${REPOSITORY_ROOT}/test/test_helper/bats-assert/load"
  load "${REPOSITORY_ROOT}/test/helper/sending"
}

__load_bats_helper

# Properly handle the container name given to tests. This makes the whole
# test suite more robust as we can be sure that the container name is
# properly set. Sometimes, we need to provide an explicit container name;
# this function eases the pain by either providing the explicitly given
# name or `CONTAINER_NAME` if it is set.
#
# @param ${1} = explicit container name [OPTIONAL]
#
# ## Attention
#
# Note that this function checks whether the name given to it starts with
# the prefix `dms-test_`. One must adhere to this naming convention.
#
# ## Panics
#
# If neither an explicit non-empty argument is given nor `CONTAINER_NAME`
# is set.
#
# ## "Calling Convention"
#
# This function should be called the following way:
#
#     local SOME_VAR=$(__handle_container_name "${X:-}")
#
# Where `X` is an arbitrary argument of the function you're calling.
#
# ## Note
#
# This function is internal and should not be used in tests.
function __handle_container_name() {
  if [[ -n ${1:-} ]] && [[ ${1:-} =~ ^dms-test_ ]]; then
    printf '%s' "${1}"
    return 0
  elif [[ -n ${CONTAINER_NAME+set} ]]; then
    printf '%s' "${CONTAINER_NAME}"
    return 0
  else
    echo 'ERROR: (helper/common.sh) Container name was either provided explicitly without the required "dms-test_" prefix, or CONTAINER_NAME is not set for implicit usage' >&2
    exit 1
  fi
}

# ? << Miscellaneous initialization functionality
# ! -------------------------------------------------------------------
# ? >> Functions to execute commands inside a container


# Execute a command inside a container with an explicit name.
#
# @param ${1} = container name
# @param ...  = command to execute
function _exec_in_container_explicit() {
  local CONTAINER_NAME=${1:?Container name must be provided when using explicit}
  shift 1
  docker exec "${CONTAINER_NAME}" "${@}"
}

# Execute a command inside the container with name ${CONTAINER_NAME}.
#
# @param ...  = command to execute
function _exec_in_container() {
  _exec_in_container_explicit "${CONTAINER_NAME:?Container name must be provided}" "${@}"
}

# Execute a command inside a container with an explicit name. The command is run with
# BATS' `run` so you can check the exit code and use `assert_`.
#
# @param ${1} = container name
# @param ...  = command to execute
function _run_in_container_explicit() {
  local CONTAINER_NAME=${1:?Container name must be provided when using explicit}
  shift 1
  run _exec_in_container_explicit "${CONTAINER_NAME}" "${@}"
}

# Execute a command inside the container with name ${CONTAINER_NAME}. The command
# is run with BATS' `run` so you can check the exit code and use `assert_`.
#
# @param ...  = command to execute
function _run_in_container() {
  _run_in_container_explicit "${CONTAINER_NAME:?Container name must be provided}" "${@}"
}

# Execute a command inside the container with name ${CONTAINER_NAME}. Moreover,
# the command is run by Bash with `/bin/bash -c`.
#
# @param ...  = command to execute with Bash
function _exec_in_container_bash() { _exec_in_container /bin/bash -c "${@}" ; }

# Execute a command inside the container with name ${CONTAINER_NAME}. The command
# is run with BATS' `run` so you can check the exit code and use `assert_`. Moreover,
# the command is run by Bash with `/bin/bash -c`.
#
# @param ...  = Bash command to execute
function _run_in_container_bash() { _run_in_container /bin/bash -c "${@}" ; }

# Run a command in Bash and filter the output given a regex.
#
# @param ${1} = command to run in Bash
# @param ${2} = regex to filter [OPTIONAL]
#
# ## Attention
#
# The regex is given to `grep -E`, so make sure it is compatible.
#
# ## Note
#
# If no regex is provided, this function will default to one that strips
# empty lines and Bash comments from the output.
function _run_in_container_bash_and_filter_output() {
  local COMMAND=${1:?Command must be provided}
  local FILTER_REGEX=${2:-^[[:space:]]*$|^ *#}

  _run_in_container_bash "${COMMAND} | grep -E -v '${FILTER_REGEX}'"
  assert_success
}

# ? << Functions to execute commands inside a container
# ! -------------------------------------------------------------------
# ? >> Functions about executing commands with timeouts

# Repeats a given command inside a container until the timeout is over.
#
# @param ${1} = timeout
# @param ${2} = container name
# @param ...  = test command for container
function _repeat_in_container_until_success_or_timeout() {
  local TIMEOUT="${1:?Timeout duration must be provided}"
  local CONTAINER_NAME="${2:?Container name must be provided}"
  shift 2

  _repeat_until_success_or_timeout \
    --fatal-test "_container_is_running ${CONTAINER_NAME}" \
    "${TIMEOUT}" \
    _exec_in_container "${@}"
}

# Repeats a given command until the timeout is over.
#
# @option --fatal-test <COMMAND EVAL STRING> = additional test whose failure aborts immediately
# @param ${1} = timeout
# @param ...  = test to run
function _repeat_until_success_or_timeout() {
  local FATAL_FAILURE_TEST_COMMAND

  if [[ "${1:-}" == "--fatal-test" ]]; then
    FATAL_FAILURE_TEST_COMMAND="${2:?Provided --fatal-test but no command}"
    shift 2
  fi

  local TIMEOUT=${1:?Timeout duration must be provided}
  shift 1

  if ! [[ "${TIMEOUT}" =~ ^[0-9]+$ ]]; then
    echo "First parameter for timeout must be an integer, received \"${TIMEOUT}\""
    return 1
  fi

  local STARTTIME=${SECONDS}

  until "${@}"; do
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

# Like `_repeat_until_success_or_timeout` . The command is run with BATS' `run`
# so you can check the exit code and use `assert_`.
#
# @param ${1} = timeout
# @param ...  = test command to run
function _run_until_success_or_timeout() {
  local TIMEOUT=${1:?Timeout duration must be provided}
  shift 1

  if [[ ! ${TIMEOUT} =~ ^[0-9]+$ ]]; then
    echo "First parameter for timeout must be an integer, received \"${TIMEOUT}\""
    return 1
  fi

  local STARTTIME=${SECONDS}

  # shellcheck disable=SC2154
  until run "${@}" && [[ ${status} -eq 0 ]]; do
    sleep 1

    if (( SECONDS - STARTTIME > TIMEOUT )); then
      echo "Timed out on command: ${*}" >&2
      return 1
    fi
  done
}

# ? << Functions about executing commands with timeouts
# ! -------------------------------------------------------------------
# ? >> Functions to wait until a condition is met


# Wait until a port is ready.
#
# @param ${1} = port
# @param ${2} = container name [OPTIONAL]
function _wait_for_tcp_port_in_container() {
  local PORT=${1:?Port number must be provided}
  local CONTAINER_NAME=$(__handle_container_name "${2:-}")

  _repeat_until_success_or_timeout \
    --fatal-test "_container_is_running ${CONTAINER_NAME}" \
    "${TEST_TIMEOUT_IN_SECONDS}" \
    _exec_in_container_bash "nc -z 0.0.0.0 ${PORT}"
}

# Wait for SMTP port (25) to become ready.
#
# @param ${1} = name of the container [OPTIONAL]
function _wait_for_smtp_port_in_container() {
  local CONTAINER_NAME=$(__handle_container_name "${1:-}")
  _wait_for_tcp_port_in_container 25
}

# Wait until the SMTP port (25) can respond.
#
# @param ${1} = name of the container [OPTIONAL]
function _wait_for_smtp_port_in_container_to_respond() {
  local CONTAINER_NAME=$(__handle_container_name "${1:-}")

  local COUNT=0
  until [[ $(_exec_in_container timeout 10 /bin/bash -c 'echo QUIT | nc localhost 25') == *'221 2.0.0 Bye'* ]]; do
    if [[ ${COUNT} -eq 20 ]]; then
      echo "Unable to receive a valid response from 'nc localhost 25' within 20 seconds"
      return 1
    fi

    sleep 1
    (( COUNT += 1 ))
  done
}

# Checks whether a service is running inside a container (${1}).
#
# @param ${1} = service name
# @param ${2} = container name [OPTIONAL]
function _should_have_service_running_in_container() {
  local SERVICE_NAME="${1:?Service name must be provided}"
  local CONTAINER_NAME=$(__handle_container_name "${2:-}")

  _run_in_container /usr/bin/supervisorctl status "${SERVICE_NAME}"
  assert_success
  assert_output --partial 'RUNNING'
}

# Wait until a service is running.
#
# @param ${1} = name of the service to wait for
# @param ${2} = container name [OPTIONAL]
function _wait_for_service() {
  local SERVICE_NAME="${1:?Service name must be provided}"
  local CONTAINER_NAME=$(__handle_container_name "${2:-}")

  _repeat_until_success_or_timeout \
    --fatal-test "_container_is_running ${CONTAINER_NAME}" \
    "${TEST_TIMEOUT_IN_SECONDS}" \
    _should_have_service_running_in_container "${SERVICE_NAME}"
}

# An account added to `postfix-accounts.cf` must wait for the `changedetector` service
# to process the update before Dovecot creates the mail account and associated storage dir.
#
# @param ${1} = mail account name
# @param ${2} = container name
function _wait_until_account_maildir_exists() {
  local MAIL_ACCOUNT=${1:?Mail account must be provided}
  local CONTAINER_NAME=$(__handle_container_name "${2:-}")

  local LOCAL_PART="${MAIL_ACCOUNT%@*}"
  local DOMAIN_PART="${MAIL_ACCOUNT#*@}"
  local MAIL_ACCOUNT_STORAGE_DIR="/var/mail/${DOMAIN_PART}/${LOCAL_PART}"

  _repeat_in_container_until_success_or_timeout 60 "${CONTAINER_NAME}" \
    /bin/bash -c "[[ -d ${MAIL_ACCOUNT_STORAGE_DIR} ]]"
}

# Wait until the mail queue is empty inside a container (${1}).
#
# @param ${1} = container name [OPTIONAL]
function _wait_for_empty_mail_queue_in_container() {
  local CONTAINER_NAME=$(__handle_container_name "${1:-}")
  local TIMEOUT=${TEST_TIMEOUT_IN_SECONDS}

  # shellcheck disable=SC2016
  _repeat_in_container_until_success_or_timeout \
    "${TIMEOUT}" \
    "${CONTAINER_NAME}" \
    /bin/bash -c '[[ $(mailq) == "Mail queue is empty" ]]'
}


# ? << Functions to wait until a condition is met
# ! -------------------------------------------------------------------
# ? >> Miscellaneous helper functions

# Adds a mail account and waits for the associated files to be created.
#
# @param ${1} = mail account name
# @param ${2} = password [OPTIONAL]
# @param ${3} = container name [OPTIONAL]
function _add_mail_account_then_wait_until_ready() {
  local MAIL_ACCOUNT=${1:?Mail account must be provided}
  local MAIL_PASS="${2:-password_not_relevant_to_test}"
  local CONTAINER_NAME=$(__handle_container_name "${3:-}")

  # Required to detect a new account and create the maildir:
  _wait_for_service changedetector "${CONTAINER_NAME}"

  _run_in_container setup email add "${MAIL_ACCOUNT}" "${MAIL_PASS}"
  assert_success

  _wait_until_account_maildir_exists "${MAIL_ACCOUNT}"
}

# Assert that the number of lines output by a previous command matches the given
# amount (${1}). `lines` is a special BATS variable updated via `run`.
#
# @param ${1} = number of lines that the output should have
function _should_output_number_of_lines() {
  # shellcheck disable=SC2154
  assert_equal "${#lines[@]}" "${1:?Number of lines not provided}"
}

# Reloads the postfix service.
#
# @param ${1} = container name [OPTIONAL]
function _reload_postfix() {
  local CONTAINER_NAME=$(__handle_container_name "${1:-}")

  # Reloading Postfix config after modifying it within 2 seconds will cause Postfix to delay reading `main.cf`:
  # WORKAROUND: https://github.com/docker-mailserver/docker-mailserver/pull/2998
  _exec_in_container touch -d '2 seconds ago' /etc/postfix/main.cf
  _exec_in_container postfix reload
}


# Get the IP of the container (${1}).
#
# @param ${1} = container name [OPTIONAL]
function _get_container_ip() {
  local TARGET_CONTAINER_NAME=$(__handle_container_name "${1:-}")
  docker inspect --format '{{ .NetworkSettings.IPAddress }}' "${TARGET_CONTAINER_NAME}"
}

# Check if a container is running.
#
# @param ${1} = container name [OPTIONAL]
function _container_is_running() {
  local TARGET_CONTAINER_NAME=$(__handle_container_name "${1:-}")
  [[ $(docker inspect -f '{{.State.Running}}' "${TARGET_CONTAINER_NAME}") == 'true' ]]
}

# Checks if the directory exists and then how many files it contains at the top-level.
#
# @param ${1} = directory
# @param ${2} = number of files that should be in ${1}
function _count_files_in_directory_in_container() {
  local DIRECTORY=${1:?No directory provided}
  local NUMBER_OF_LINES=${2:?No line count provided}

  _should_have_content_in_directory "${DIRECTORY}" '-type f'
  _should_output_number_of_lines "${NUMBER_OF_LINES}"
}

# Checks if the directory exists and then list the top-level content.
#
# @param ${1} = directory
# @param ${2} = Additional options to `find`
function _should_have_content_in_directory() {
  local DIRECTORY=${1:?No directory provided}
  local FIND_OPTIONS=${2:-}

  _run_in_container_bash "[[ -d ${DIRECTORY} ]] && find ${DIRECTORY} -mindepth 1 -maxdepth 1 ${FIND_OPTIONS} -printf '%f\n'"
  assert_success
}

# Filters a service's logs (under `/var/log/supervisor/<SERVICE>.log`) given
# a specific string.
#
# @param ${1} = service name
# @param ${2} = string to filter by
# @param ${3} = container name [OPTIONAL]
#
# ## Attention
#
# The string given to this function is interpreted by `grep -E`, i.e.
# as a regular expression. In case you use characters that are special
# in regular expressions, you need to escape them!
function _filter_service_log() {
  local SERVICE=${1:?Service name must be provided}
  local STRING=${2:?String to match must be provided}
  local CONTAINER_NAME=$(__handle_container_name "${3:-}")
  local FILE="/var/log/supervisor/${SERVICE}.log"

  # Fallback to alternative log location:
  [[ -f ${FILE} ]] || FILE="/var/log/mail/${SERVICE}.log"
  _run_in_container grep -E "${STRING}" "${FILE}"
}

# Like `_filter_service_log` but asserts that the string was found.
#
# @param ${1} = service name
# @param ${2} = string to filter by
# @param ${3} = container name [OPTIONAL]
#
# ## Attention
#
# The string given to this function is interpreted by `grep -E`, i.e.
# as a regular expression. In case you use characters that are special
# in regular expressions, you need to escape them!
function _service_log_should_contain_string() {
  local SERVICE=${1:?Service name must be provided}
  local STRING=${2:?String to match must be provided}
  local CONTAINER_NAME=$(__handle_container_name "${3:-}")

  _filter_service_log "${SERVICE}" "${STRING}"
  assert_success
}

# Filters the mail log for lines that belong to a certain email identified
# by its ID. You can obtain the ID of an email you want to send by using
# `_send_email_and_get_id`.
#
# @param ${1} = email ID
# @param ${2} = container name [OPTIONAL]
function _print_mail_log_for_id() {
  local MAIL_ID=${1:?Mail ID must be provided}
  local CONTAINER_NAME=$(__handle_container_name "${2:-}")

  _run_in_container grep -F "${MAIL_ID}" /var/log/mail.log
}

# ? << Miscellaneous helper functions
# ! -------------------------------------------------------------------
