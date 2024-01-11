#!/bin/bash

# shellcheck disable=SC2034,SC2155

# ? ABOUT: Functions defined here help with sending emails in tests.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!

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
# The first argument has to be the name of the variable that the e-mail ID is stored in.
# The second argument **can** be the flag `--expect-rejection`.
#
# - If this flag is supplied, the function does not check whether the whole mail delivery
#   transaction was successful. Additionally the queue ID will be retrieved differently.
# - CAUTION: It must still be possible to `grep` for the Message-ID that Postfix
#   generated in the mail log; otherwise this function fails.
#
# The rest of the arguments are the same as `_send_email`.
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
  # Export the variable denoted by ${1} so everyone has access
  export "${1:?Mail ID must be set for _send_email_and_get_id}"
  # Get a "reference" to the content of the variable denoted by ${1} so we can manipulate the content
  local -n ID_ENV_VAR_REF=${1:?}
  # Prepare the message ID header here because we will shift away ${1} later
  local MID="<${1}@dms-tests>"
  # Get rid of ${1} so only the arguments for swaks remain
  shift 1

  local QUEUE_ID
  # The unique ID Postfix (and other services) use may be different in length
  # on different systems (e.g. amd64 (11) vs aarch64 (10)). Hence, we use a
  # range to safely capture it.
  local QUEUE_ID_REGEX='[A-Z0-9]{9,12}'

  _wait_for_empty_mail_queue_in_container
  local OUTPUT=$(_send_email "${@}" --header "Message-Id: ${MID}")
  _wait_for_empty_mail_queue_in_container

  # We store Postfix's queue ID first
  ID_ENV_VAR_REF=$(_exec_in_container tac /var/log/mail.log                    \
    | grep -E "postfix/cleanup.*: ${QUEUE_ID_REGEX}:.*message-id=${MID}" \
    | grep -E --only-matching --max-count 1 "${QUEUE_ID_REGEX}" || :)
  # But we also requre potential Dovecot sieve output, which requires the mesage ID,
  # so we need to provide the message ID too.
  ID_ENV_VAR_REF+="|${MID}"

  # Last but not least, we perform plausibility checks on the IDs.
  assert_not_equal "${ID_ENV_VAR_REF}" ''
  run echo "${ID_ENV_VAR_REF}"
  assert_line --regexp "^${QUEUE_ID_REGEX}\|${MID}$"
}
