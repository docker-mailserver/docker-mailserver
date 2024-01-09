#!/bin/bash

# shellcheck disable=SC2034,SC2155

# ? ABOUT: Functions defined here help with sending emails in tests.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!

# Parse the arguments given to `_send_email` and `_send_email_unchecked`.
# Outputs the `swaks` command to later be executed by the calling function.
#
# ## Note
#
# This is an internal support function, it should not be used directly by tests.
function __parse_swaks_arguments() {
  [[ -v CONTAINER_NAME ]] || return 1

  # Parameter defaults common to our testing needs:
  local EHLO='mail.external.tld'
  local FROM='user@external.tld'
  local TO='user1@localhost.localdomain'
  local SERVER='0.0.0.0'
  local PORT=25
  # Extra options for `swaks` that aren't covered by the default options above:
  local ADDITIONAL_SWAKS_OPTIONS=()
  local DATA_WAS_SUPPLIED=0

  while [[ ${#} -gt 0 ]]; do
    case "${1}" in
      ( '--ehlo' )   EHLO=${2:?--ehlo given but no argument}     ; shift 2 ;;
      ( '--from' )   FROM=${2:?--from given but no argument}     ; shift 2 ;;
      ( '--to' )     TO=${2:?--to given but no argument}         ; shift 2 ;;
      ( '--server' ) SERVER=${2:?--server given but no argument} ; shift 2 ;;
      ( '--port' )   PORT=${2:?--port given but no argument}     ; shift 2 ;;
      ( '--data' )
        ADDITIONAL_SWAKS_OPTIONS+=('--data')
        local FILE_PATH="/tmp/docker-mailserver-test/emails/${2:?--data given but no argument provided}"
        if _exec_in_container_bash "[[ -e ${FILE_PATH} ]]"; then
          ADDITIONAL_SWAKS_OPTIONS+=("@${FILE_PATH}")
        else
          ADDITIONAL_SWAKS_OPTIONS+=("'${2}'")
        fi
        shift 2
        DATA_WAS_SUPPLIED=1
        ;;
      ( * ) ADDITIONAL_SWAKS_OPTIONS+=("'${1}'") ; shift 1 ;;
    esac
  done

  if [[ ${DATA_WAS_SUPPLIED} -eq 0 ]]; then
    # Fallback template (without the implicit `Message-Id` + `X-Mailer` headers from swaks):
    # NOTE: It is better to let Postfix generate and append the `Message-Id` header itself,
    #       as it will contain the Queue ID for tracking in logs (which is also returned in swaks output).
    ADDITIONAL_SWAKS_OPTIONS+=('--data')
    ADDITIONAL_SWAKS_OPTIONS+=("'Date: %DATE%\nTo: %TO_ADDRESS%\nFrom: %FROM_ADDRESS%\nSubject: test %DATE%\n%NEW_HEADERS%\n%BODY%\n'")
  fi

  echo "swaks --server '${SERVER}' --port '${PORT}' --ehlo '${EHLO}' --from '${FROM}' --to '${TO}' ${ADDITIONAL_SWAKS_OPTIONS[*]}"
}

# Sends a mail from the container named by the environment variable `CONTAINER_NAME`
# to the same or another container.
#
# To send a custom email:
# 1. Create a file at `test/files/<TEST FILE>`
# 2. Provide `<TEST FILE>` as an argument to this function.
#
# Parameters include all options that one can supply to `swaks` itself.
# The `--data` parameter expects a value of either:
# - A relative path from `test/files/emails/`
# - An "inline" data string (e.g., `Date: 1 Jan 2024\nSubject: This is a test`)
#
# ## Output
#
# This functions prints the output of the transaction that `swaks` prints.
#
# ## Attention
#
# This function assumes `CONTAINER_NAME` to be properly set (to the container
# name the command should be executed in)!
#
# This function will send the email in an "asynchronous" fashion,
# it will return without waiting for the Postfix mail queue to be emptied.
#
# This functions performs **no** implicit `assert_success` to check whether the
# e-mail transaction was successful. If this is not desirable, use `_send_email`.
# If you anticipate the sending to succeed, use `_send_email` instead.
function _send_email_unchecked() {
  local COMMAND_STRING=$(__parse_swaks_arguments "${@}")
  _run_in_container_bash "${COMMAND_STRING}"
  local RETURN_VALUE=${?}
  # shellcheck disable=SC2154
  echo "${output}"
  return "${RETURN_VALUE}"
}

# Sends a mail from the container named by the environment variable `CONTAINER_NAME`
# to the same or another container.
#
# To send a custom email:
# 1. Create a file at `test/files/<TEST FILE>`
# 2. Provide `<TEST FILE>` as an argument to this function.
#
# Parameters include all options that one can supply to `swaks` itself.
# The `--data` parameter expects a value of either:
# - A relative path from `test/files/emails/`
# - An "inline" data string (e.g., `Date: 1 Jan 2024\nSubject: This is a test`)
#
# ## Output
#
# This functions prints the output of the transaction that `swaks` prints.
#
# ## Attention
#
# This function assumes `CONTAINER_NAME` to be properly set (to the container
# name the command should be executed in)!
#
# This function will send the email in an "asynchronous" fashion,
# it will return without waiting for the Postfix mail queue to be emptied.
function _send_email() {
  local COMMAND_STRING=$(__parse_swaks_arguments "${@}")
  _run_in_container_bash "${COMMAND_STRING}"
  assert_success
  # shellcheck disable=SC2154
  echo "${output}"
}

# Like `_send_email` with two major differences:
#
# 1. this function waits for the mail to be processed; there is no asynchronicity
#    because filtering the logs in a synchronous way is easier and safer;
# 2. this function takes the name of a variable and inserts IDs one can later
#    filter by to check logs.
#
# No. 2 is especially useful in case you send more than one email in a single
# test file and need to assert certain log entries for each mail individually.
#
# The first argument has to be the name of the variable that the e-mail ID is stored
# in. The second argument **can** be the flag `--unchecked`; if this flag is supplied,
# the function uses `_send_email_unchecked` instead of `_send_email`. This avoids the
# `assert_success`. Be warned though this is only required in special situations where
# it is still possible to `grep` for the Message-ID that Postfix generated, -
# otherwise this function fails. The rest of the arguments are the same as `_send_email`.
#
# ## Attention
#
# This function assumes `CONTAINER_NAME` to be properly set (to the container
# name the command should be executed in)!
#
# ## Safety
#
# This functions assumes **no concurrent sending of emails to the same container**!
# If two clients send simultaneously, there is no guarantee the correct ID is
# chosen. Sending more than one mail at any given point in time with this function
# is UNDEFINED BEHAVIOR!
function _send_email_and_get_id() {
  # Get the name of the variable that the ID is stored in
  local ID_ENV_VAR_NAME="${1:?Mail ID must be set for _send_email_and_get_id}"
  # Get a "reference" to the content of ID_ENV_VAR_NAME so we can manipulate the content
  local -n ID_ENV_VAR_REF=${ID_ENV_VAR_NAME}
  # Export the variable so everyone has access
  # shellcheck disable=SC2163
  export "${ID_ENV_VAR_NAME}"
  shift 1

  local QUEUE_ID MESSAGE_ID
  # The unique ID Postfix (and other services) use may be different in length
  # on different systems (e.g. amd64 (11) vs aarch64 (10)). Hence, we use a
  # range to safely capture it.
  local QUEUE_ID_REGEX='[A-Z0-9]{9,12}'
  local MESSAGE_ID_REGEX="[0-9]{14}\\.${QUEUE_ID_REGEX}"

  _wait_for_empty_mail_queue_in_container
  if [[ ${1} == --unchecked ]]; then
    shift 1
    local OUTPUT=$(_send_email_unchecked "${@}")
    QUEUE_ID=$(_exec_in_container tac /var/log/mail.log       \
      | grep -E "postfix/smtpd.*: ${QUEUE_ID_REGEX}: client=" \
      | grep -E -m 1 -o '[A-Z0-9]{9,12}' || :)
  else
    local OUTPUT=$(_send_email "${@}")
    QUEUE_ID=$(grep -F 'queued as' <<< "${OUTPUT}" | grep -E -o "${QUEUE_ID_REGEX}$")
  fi
  _wait_for_empty_mail_queue_in_container

  MESSAGE_ID=$(_exec_in_container tac /var/log/mail.log \
    | grep -E "message-id=<${MESSAGE_ID_REGEX}@"        \
    | grep -E -m 1 -o "${MESSAGE_ID_REGEX}" || :)

  ID_ENV_VAR_REF="${QUEUE_ID}|${MESSAGE_ID}"

  # Last but not least, we perform plausibility checks on the IDs.
  assert_not_equal "${ID_ENV_VAR_REF}" ''
  run echo "${ID_ENV_VAR_REF}"
  assert_line --regexp "^${QUEUE_ID_REGEX}|${MESSAGE_ID_REGEX}$"
}
