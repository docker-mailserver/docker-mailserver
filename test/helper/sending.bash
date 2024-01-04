#!/bin/bash

# shellcheck disable=SC2034,SC2155

# ? ABOUT: Functions defined here help with sending emails in tests.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!

# Sends a mail from localhost (127.0.0.1) to a container. To send
# a custom email, create a file at `test/files/<TEST FILE>`,
# and provide `<TEST FILE>` as an argument to this function.
#
# Parameters include all options that one can supply to `swaks`
# itself. The `--data` parameter expects a relative path from `emails/`
# where the contents will be implicitly provided to `swaks` via STDIN.
#
# This functions performs **no** implicit `assert_success` to check whether
# the e-mail transaction was successful. If this is not desirable, use
# `_send_email`.
#
# ## Attention
#
# This function assumes `CONTAINER_NAME` to be properly set (to the container
# name the command should be executed in)!
#
# This function will just send the email in an "asynchronous" fashion, i.e. it will
# send the email but it will not make sure the mail queue is empty after the mail
# has been sent.
function _send_email_unchecked() {
  [[ -v CONTAINER_NAME ]] || return 1

  # Parameter defaults common to our testing needs:
  local EHLO='mail.external.tld'
  local FROM='user@external.tld'
  local TO='user1@localhost.localdomain'
  local SERVER='0.0.0.0'
  local PORT=25
  # Extra options for `swaks` that aren't covered by the default options above:
  local ADDITIONAL_SWAKS_OPTIONS=()
  # Specifically for handling `--data` option below:
  local FINAL_SWAKS_OPTIONS=()

  while [[ ${#} -gt 0 ]]; do
    case "${1}" in
      ( '--ehlo' )   EHLO=${2:?--ehlo given but no argument}     ; shift 2 ;;
      ( '--from' )   FROM=${2:?--from given but no argument}     ; shift 2 ;;
      ( '--to' )     TO=${2:?--to given but no argument}         ; shift 2 ;;
      ( '--server' ) SERVER=${2:?--server given but no argument} ; shift 2 ;;
      ( '--port' )   PORT=${2:?--port given but no argument}     ; shift 2 ;;
      ( '--data' )
        local TEMPLATE_FILE="/tmp/docker-mailserver-test/emails/${2:?--data given but no argument provided}.txt"
        FINAL_SWAKS_OPTIONS+=('--data')
        FINAL_SWAKS_OPTIONS+=('-')
        FINAL_SWAKS_OPTIONS+=('<')
        FINAL_SWAKS_OPTIONS+=("${TEMPLATE_FILE}")
        shift 2
        ;;
      ( * ) ADDITIONAL_SWAKS_OPTIONS+=("${1}") ; shift 1 ;;
    esac
  done

  _run_in_container_bash "swaks --server ${SERVER} --port ${PORT} --ehlo ${EHLO} --from ${FROM} --to ${TO} ${ADDITIONAL_SWAKS_OPTIONS[*]} ${FINAL_SWAKS_OPTIONS[*]}"
# Sends a mail from localhost (127.0.0.1) to a container. To send
# a custom email, create a file at `test/files/<TEST FILE>`,
# and provide `<TEST FILE>` as an argument to this function.
#
# Parameters include all options that one can supply to `swaks`
# itself. The `--data` parameter expects a relative path from `emails/`
# where the contents will be implicitly provided to `swaks` via STDIN.
#
# This functions performs an implicit `assert_success` to check whether
# the e-mail transaction was successful. If this is not desirable, use
# `_send_email_unchecked`.
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
  _send_email_unchecked "${@}"
  assert_success
}

# Like `_send_email` with two major differences:
#
# 1. this function waits for the mail to be processed; there is no asynchronicity
#    because filtering the logs in a synchronous way is easier and safer;
# 2. this function takes the name of a variable and inserts ID(s) one can later
#    filter by to check logs.
#
# No. 2 is especially useful in case you send more than one email in a single
# test file and need to assert certain log entries for each mail individually.
#
# The first argument has to be the name of the variable that the e-mail ID is stored
# in. The rest of the arguments are the same as `_send_email`.
#
# ## Attention
#
# This function assumes `CONTAINER_NAME` to be properly set (to the container
# name the command should be executed in)!
#
# Moreover, if `--data <DATA>` is specified, the additional header added implicitly
# (with `--add-header`) may get lost, so pay attention to the data having the token
# to place additonal headers into.
#
# ## Safety
#
# This functions assumes **no concurrent sending of emails to the same container**!
# If two clients send simultaneously, there is no guarantee the correct ID is
# chosen. Sending more than one mail at any given point in time with this function
# is UNDEFINED BEHAVIOR!
function _send_email_and_get_id() {
  # Get the name of the variable that the ID is stored in
  local ID_NAME="${1:?Mail ID must be set for _send_email_and_get_id}"
  # Get a "reference" so wan manipulate the ID
  local -n MAIL_ID=${ID_NAME}
  # Export the variable so everyone has access
  # `:?` is required, otherwise ShellCheck complains
  export "${ID_NAME:?}"
  shift 1

  _wait_for_empty_mail_queue_in_container
  _send_email "${@}" --add-header "Message-Id: ${ID_NAME}"
  _wait_for_empty_mail_queue_in_container

  # The unique ID Postfix (and other services) use may be different in length
  # on different systems (e.g. amd64 (11) vs aarch64 (10)). Hence, we use a
  # range to safely capture it.
  #
  # First, we define the regular expressions we need for capturing the IDs.
  local REGEX_ID_PART_ONE='[A-Z0-9]{9,12}'
  local REGEX_ID_PART_TWO="$(date +'%Y%m%d')[0-9]+\\.[0-9]+"
  # The first line Postfix logs looks something like this:
  #
  # Jan  4 16:09:19 mail postfix/cleanup[1188]: 07B29249A7: message-id=MAIL_ID_HEADER
  #
  # where 07B29249A7 is one of the IDs we are searching for and MAIL_ID_HEADER is the ID_NAME.
  # Note that we are searching the log in reverse, which is important to get the correct ID.
  MAIL_ID=$(_exec_in_container tac /var/log/mail.log \
    | grep -F -m 1 "message-id=${ID_NAME}" \
    | grep -E -o "${REGEX_ID_PART_ONE}")
  # We additionally grep for another ID that Postfix (and later mechanisms like Sieve) use (additionally),
  # and the line looks something like this:
  #
  # Jan  4 16:09:19 mail postfix/cleanup[1188]: 07B29249A7: message-id=<20240104160919.001289@mail.example.test>
  #
  # where 20240104160919 is the other ID we are searching for. Note that the date is encoded by this ID.
  # We exploit the fact that MAIL_ID is already on the line, so we can search for it efficiently. Moreover,
  # these lines appear close to each other (usually next to each other). When looking in reverse.
  MAIL_ID+="|$(_exec_in_container grep -F "${MAIL_ID}: message-id=" /var/log/mail.log \
    | grep -E -o "${REGEX_ID_PART_TWO}")"

  # Last but not least, we perform plausibility checks on the IDs.
  assert_not_equal "${MAIL_ID}" ''
  run echo "${MAIL_ID}"
  assert_line --regexp "^${REGEX_ID_PART_ONE}|${REGEX_ID_PART_TWO}$"
}
