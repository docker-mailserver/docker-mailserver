#!/bin/bash

# shellcheck disable=SC2034,SC2155

# ? ABOUT: Functions defined here help with sending emails in tests.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!

# Sends a mail from localhost (127.0.0.1) to a container. To send
# a custom email, create a file at `test/files/<TEST FILE>`,
# and provide `<TEST FILE>` as an argument to this function.
#
# @param ${1} = template file (path) name without .txt suffix
# @param ...  = options that `swaks` accepts
#
# ## Attention
#
# This function assumes `CONTAINER_NAME` to be properly set (to the container
# name the command should be executed in)!
#
# This function will just send the email in an "asynchronous" fashion, i.e. it will
# send the email but it will not make sure the mail queue is empty after the mail
# has been sent.
function _send_email() {
  [[ -v CONTAINER_NAME ]] || return 1

  local HELO='mail.external.tld'
  local FROM='user@external.tld'
  local TO='user1@localhost.localdomain'
  local SERVER='0.0.0.0'
  local PORT=25
  local MORE_SWAKS_OPTIONS=()

  while [[ ${#} -gt 1 ]]; do
    case "${1}" in
      ( '--helo' )   HELO=${2:?--helo given but no argument}     ; shift 2 ;;
      ( '--from' )   FROM=${2:?--from given but no argument}     ; shift 2 ;;
      ( '--to' )     TO=${2:?--to given but no argument}         ; shift 2 ;;
      ( '--server' ) SERVER=${2:?--server given but no argument} ; shift 2 ;;
      ( '--port' )   PORT=${2:?--port given but no argument}     ; shift 2 ;;
      ( * )          MORE_SWAKS_OPTIONS+=("${1}")                ; shift 1 ;;
    esac
  done

  local TEMPLATE_FILE="/tmp/docker-mailserver-test/emails/${1:?Must provide name of template file}.txt"

  echo "CONTAINER: ${CONTAINER_NAME} | COMMAND: swaks --server ${SERVER} --port ${PORT} --helo ${HELO} --from ${FROM} --to ${TO} ${MORE_SWAKS_OPTIONS[*]} --data - < ${TEMPLATE_FILE}" >/tmp/log

  _run_in_container_bash "swaks --server ${SERVER} --port ${PORT} --helo ${HELO} --from ${FROM} --to ${TO} ${MORE_SWAKS_OPTIONS[*]} --data - < ${TEMPLATE_FILE}"
}

# Like `_send_email` with two major differences:
#
# 1. this function waits for the mail to be processed; there is no asynchronicity
#    because filtering the logs in a synchronous way is easier and safer!
# 2. this function prints an ID one can later filter by to check logs
#
# No. 2 is especially useful in case you send more than one email in a single
# test file and need to assert certain log entries for each mail individually.
#
# @param ${1} = template file (path) name without .txt suffix
# @param ${2} = config file path name without .cfg suffix [OPTIONAL] (default: ${1})
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
  [[ -v CONTAINER_NAME ]] || return 1

  _wait_for_empty_mail_queue_in_container
  _send_email "${@}"
  _wait_for_empty_mail_queue_in_container

  local MAIL_ID
  # The unique ID Postfix (and other services) use may be different in length
  # on different systems (e.g. amd64 (11) vs aarch64 (10)). Hence, we use a
  # range to safely capture it.
  MAIL_ID=$(_exec_in_container tac /var/log/mail.log              \
    | grep -E -m 1 'postfix/smtpd.*: [A-Z0-9]+: client=localhost' \
    | grep -E -o '[A-Z0-9]{9,12}' || true)

  assert_not_equal "${MAIL_ID}" ''
  echo "${MAIL_ID}"
}
