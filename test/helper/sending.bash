#!/bin/bash

# ? ABOUT: Functions defined here help with sending emails in tests.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!
# ! ATTENTION: Functions prefixed with `__` are intended for internal use within
# !            this file (or other helpers) only, not in tests.

# shellcheck disable=SC2034,SC2155

# Sends an e-mail from the container named by the environment variable `CONTAINER_NAME`
# to the same or another container.
#
# To send a custom email, you can
#
# 1. create a file at `test/files/<TEST FILE>` and provide `<TEST FILE>` via `--data` as an argument to this function;
# 2. use this function without the `--data` argument, in which case we provide a default;
# 3. provide data inline (`--data <INLINE DATA>`).
#
# The very first parameter **may** be `--expect-rejection` - use it of you expect the mail transaction to not finish
# successfully. All other (following) parameters include all options that one can supply to `swaks` itself.
# As mentioned before, the `--data` parameter expects a value of either:
#
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
  local RETURN_VALUE=0
  local COMMAND_STRING

  function __parse_arguments() {
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

  if [[ ${1:-} == --expect-rejection ]]; then
    shift 1
    COMMAND_STRING=$(__parse_arguments "${@}")
    _run_in_container_bash "${COMMAND_STRING}"
    RETURN_VALUE=${?}
  else
    COMMAND_STRING=$(__parse_arguments "${@}")
    _run_in_container_bash "${COMMAND_STRING}"
    assert_success
  fi

  # shellcheck disable=SC2154
  echo "${output}"
  return "${RETURN_VALUE}"
}

# Construct the value for a 'Message-ID' header.
# For tests we use only the local-part to identify mail activity in logs. The rest of the value is fixed.
#
# A Message-ID header value should be in the form of: `<local-part@domain-part>`
# https://en.wikipedia.org/wiki/Message-ID
# https://datatracker.ietf.org/doc/html/rfc5322#section-3.6.4
#
# @param ${1} = The local-part of a Message-ID header value (`<local-part@domain-part>`)
function __construct_msgid() {
  local MSG_ID_LOCALPART=${1:?The local-part for MSG_ID was not provided}
  echo "<${MSG_ID_LOCALPART}@dms-tests>"
}

# Like `_send_email` but adds a "Message-ID: ${1}@dms-tests>" header,
# which allows for filtering logs later.
#
# @param ${1} = The local-part of a Message-ID header value (`<local-part@domain-part>`)
function _send_email_with_msgid() {
  local MSG_ID=$(__construct_msgid "${1:?The local-part for MSG_ID was not provided}")
  shift 1

  _send_email "${@}" --header "Message-ID: ${MSG_ID}"
}

# Send a spam e-mail by utilizing GTUBE.
#
# Extra arguments given to this function will be supplied by `_send_email_with_msgid` directly.
function _send_spam() {
  _send_email_with_msgid 'dms-test-email-spam' "${@}" \
    --from 'spam@external.tld' \
    --body 'XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X'
}
