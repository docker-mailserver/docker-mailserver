#!/bin/bash

# ? ABOUT: Functions defined here aid in working with logs and filtering them.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!

# shellcheck disable=SC2034,SC2155

# Assert that the number of lines output by a previous command matches the given amount (${1}).
# `lines` is a special BATS variable updated via `run`.
#
# @param ${1} = number of lines that the output should have
function _should_output_number_of_lines() {
  # shellcheck disable=SC2154
  assert_equal "${#lines[@]}" "${1:?Number of lines not provided}"
}

# Filters a service's logs (under `/var/log/supervisor/<SERVICE>.log`) given a specific string.
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

# Filters the mail log by the given MSG_ID (Message-ID) parameter,
# printing log lines which include the associated Postfix Queue ID.
#
# @param ${1} = The local-part of a Message-ID header value (`<local-part@domain-part>`)
function _print_mail_log_of_queue_id_from_msgid() {
  # A unique ID Postfix generates for tracking queued mail as it's processed.
  # The length can vary (as per the postfix docs). Hence, we use a range to safely capture it.
  # https://github.com/docker-mailserver/docker-mailserver/pull/3747#discussion_r1446679671
  local QUEUE_ID_REGEX='[A-Z0-9]{9,12}'

  local MSG_ID=$(__construct_msgid "${1:?The local-part for MSG_ID was not provided}")
  shift 1

  _wait_for_empty_mail_queue_in_container

  QUEUE_ID=$(_exec_in_container tac /var/log/mail.log                    \
    | grep -E "postfix/cleanup.*: ${QUEUE_ID_REGEX}:.*message-id=${MSG_ID}" \
    | grep -E --only-matching --max-count 1 "${QUEUE_ID_REGEX}" || :)

  # We perform plausibility checks on the IDs.
  assert_not_equal "${QUEUE_ID}" ''
  run echo "${QUEUE_ID}"
  assert_line --regexp "^${QUEUE_ID_REGEX}$"

  # Postfix specific logs:
  _filter_service_log 'mail' "${QUEUE_ID}"
}

# A convenience method that filters for Dovecot specific logs with a `msgid` field that matches the MSG_ID input.
#
# @param ${1} = The local-part of a Message-ID header value (`<local-part@domain-part>`)
function _print_mail_log_for_msgid() {
  local MSG_ID=$(__construct_msgid "${1:?The local-part for MSG_ID was not provided}")
  shift 1

  # Dovecot specific logs:
  _filter_service_log 'mail' "msgid=${MSG_ID}"
}
