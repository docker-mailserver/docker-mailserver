#!/bin/bash

# shellcheck disable=SC2034,SC2155

# ? ABOUT: Functions defined here help with sending emails in tests.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!

# Sends a mail from localhost (127.0.0.1) to a container. To send
# a custom email, create a file at `test/test-files/<TEST FILE>`,
# and provide `<TEST FILE>` as an argument to this function.
#
# @param ${1} = template file (path) name
# @param ${2} = container name [OPTIONAL] (can be empty if CONTAINER_NAME is set)
# @param ${3} = parameters for `nc` [OPTIONAL] (default: `0.0.0.0 25`)
#
# ## Attention
#
# This function will just send the email in an "asynchronous" fashion, i.e. it will
# send the email but it will not make sure the mail queue is empty after the mail
# has been sent.
function _send_email() {
  local TEMPLATE_FILE=${1:?Must provide name of template file}
  local CONTAINER_NAME=$(__handle_container_name "${2:-}")

  _run_in_container_bash "nc ${3:-0.0.0.0 25} < /tmp/docker-mailserver-test/${TEMPLATE_FILE}.txt"
  assert_success
}

# Like `_send_mail` with two major differences:
#
# 1. this function waits for the mail to be processed; there is no asynchronicity
#    because filtering the logs in a synchronous way is easier and safer!
# 2. this function prints an ID one can later filter by to check logs
#
# No. 2 is especially useful in case you send more than one email in a single
# test file and need to assert certain log entries for each mail individually.
#
# @param ${1} = template file (path) name
# @param ${2} = container name [OPTIONAL]
#
# ## Safety
#
# This functions assumes **no concurrent sending of emails to the same container**!
# If two clients send simultaneously, there is no guarantee the correct ID is
# chosen. Sending more than one mail at any given point in time with this function
# is UNDEFINED BEHAVIOR!
function _send_mail_and_get_id() {
  local TEMPLATE_FILE=${1:?Must provide name of template file}
  local CONTAINER_NAME=$(__handle_container_name "${2:-}")
  local MAIL_ID

  _wait_for_empty_mail_queue_in_container
  _send_email "${TEMPLATE_FILE}"
  _wait_for_empty_mail_queue_in_container

  # The unique ID Postfix (and other services) use may be different in length
  # on different systems (e.g. amd64 (11) vs aarch64 (10)). Hence, we use a
  # range to safely capture it.
  MAIL_ID=$(_exec_in_container tac /var/log/mail.log              \
    | grep -E -m 1 'postfix/smtpd.*: [A-Z0-9]+: client=localhost' \
    | grep -E -o '[A-Z0-9]{9,12}' || true)

  run bash -c "-z ${MAIL_ID}"
  assert_success 'Could not obtain mail ID - aborting!'

  echo "${MAIL_ID}"
}
