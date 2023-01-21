#!/bin/bash

# TODO: Functions need documentation (adhere to doc conventions!)
# ? ABOUT: Functions defined here aid with the change-detection functionality of DMS.

# ! -------------------------------------------------------------------
# ? >> Miscellaneous initialization functionality

# shellcheck disable=SC2155

load "${REPOSITORY_ROOT}/test/helper/common"

# ? << Miscellaneous initialization functionality
# ! -------------------------------------------------------------------
# ? >> Change-detection helpers

# TODO documentation @polarathene
#
# ## Note
#
# Relies on ENV `LOG_LEVEL=debug` or higher
#
# @param ${1} = expected count [OPTIONAL]
# @param ${2} = container name [OPTIONAL]
function _wait_until_expected_count_is_matched() {
  function __get_count() {
    # NOTE: `|| true` required due to `set -e` usage:
    # https://github.com/docker-mailserver/docker-mailserver/pull/2997#discussion_r1070583876
    _exec_in_container grep --count "${MATCH_CONTENT}" "${MATCH_IN_LOG}" || true
  }

  # WARNING: Keep in mind it is a '>=' comparison.
  # If you provide an explict count to match, ensure it is not too low to cause a false-positive.
  function __has_expected_count() {
    # shellcheck disable=SC2317
    [[ $(__get_count) -ge "${EXPECTED_COUNT}" ]]
  }

  local EXPECTED_COUNT=${1:-}
  local CONTAINER_NAME=$(__handle_container_name "${2:-}")

  # Ensure the container is configured with the required `LOG_LEVEL` ENV:
  assert_regex "$(_exec_in_container env | grep '^LOG_LEVEL=')" '=(debug|trace)$'

  # Default behaviour is to wait until one new match is found (eg: incremented),
  # unless explicitly set (useful for waiting on a min count to be reached):
  #
  # +1 of starting count if EXPECTED_COUNT is empty
  [[ -n ${EXPECTED_COUNT} ]] || EXPECTED_COUNT=$(( $(__get_count) + 1 ))

  _repeat_until_success_or_timeout 20 __has_expected_count
}

function _wait_until_change_detection_event_begins() {
  local MATCH_CONTENT='Change detected'
  local MATCH_IN_LOG='/var/log/supervisor/changedetector.log'

  _wait_until_expected_count_is_matched "${@}"
}

# ## Note
#
# Change events can start and finish all within < 1 sec.
# Reliably track the completion of a change event by counting events.
function _wait_until_change_detection_event_completes() {
  # shellcheck disable=SC2034
  local MATCH_CONTENT='Completed handling of detected change'
  # shellcheck disable=SC2034
  local MATCH_IN_LOG='/var/log/supervisor/changedetector.log'

  _wait_until_expected_count_is_matched "${@}"
}

function _get_logs_since_last_change_detection() {
  # shellcheck disable=SC2034
  local CONTAINER_NAME=$(__handle_container_name "${1:-}")
  local MATCH_IN_FILE='/var/log/supervisor/changedetector.log'
  local MATCH_STRING='Change detected'

  # Read file in reverse, collect lines until match with sed is found,
  # then stop and return these lines back in original order (flipped again through tac):
  _exec_in_container_bash "tac ${MATCH_IN_FILE} | sed '/${MATCH_STRING}/q' | tac"
}

# ? << Change-detection helpers
# ! -------------------------------------------------------------------
