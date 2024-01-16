#!/bin/bash

# ? ABOUT: Functions defined here aid in working with logs and filtering them.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!

# shellcheck disable=SC2034,SC2155

# Assert that the number of lines output by a previous command matches the given
# amount (${1}). `lines` is a special BATS variable updated via `run`.
#
# @param ${1} = number of lines that the output should have
function _should_output_number_of_lines() {
  # shellcheck disable=SC2154
  assert_equal "${#lines[@]}" "${1:?Number of lines not provided}"
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
  _run_in_container grep -i -E "${STRING}" "${FILE}"
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
  _filter_service_log "${@}"
  assert_success
}

# Like `_filter_service_log` but asserts that the string was not found.
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
function _service_log_should_not_contain_string() {
  _filter_service_log "${@}"
  assert_failure
}

# Filters the mail log according to MID (Message-ID) and prints lines
# of the mail log that fit Postfix's queue ID for the given message ID.
#
# @param ${1} = message ID part before '@'
function _print_mail_log_of_queue_id_from_mid() {
  # The unique ID Postfix (and other services) use may be different in length
  # on different systems. Hence, we use a range to safely capture it.
  local QUEUE_ID_REGEX='[A-Z0-9]{9,12}'

  local MID=$(__construct_mid "${1:?Left-hand side of MID missing}")
  shift 1

  _wait_for_empty_mail_queue_in_container

  QUEUE_ID=$(_exec_in_container tac /var/log/mail.log                    \
    | grep -E "postfix/cleanup.*: ${QUEUE_ID_REGEX}:.*message-id=${MID}" \
    | grep -E --only-matching --max-count 1 "${QUEUE_ID_REGEX}" || :)

  # We perform plausibility checks on the IDs.
  assert_not_equal "${QUEUE_ID}" ''
  run echo "${QUEUE_ID}"
  assert_line --regexp "^${QUEUE_ID_REGEX}$"

  _filter_service_log 'mail' "${QUEUE_ID}"
}

# Filters the mail log according to MID (Message-ID) and prints lines
# of the mail log that fit lines with the pattern `msgid=${1}@dms-test`.
#
# @param ${1} = message ID part before '@'
function _print_mail_log_for_msgid() {
  local MID=$(__construct_mid "${1:?Left-hand side of MID missing}")
  shift 1

  _filter_service_log 'mail' "msgid=${MID}"
}
