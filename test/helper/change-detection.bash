#!/bin/bash

load "${REPOSITORY_ROOT}/test/helper/common"

function wait_until_change_detection_event_begins() {
  local MATCH_CONTENT='Change detected'
  local MATCH_IN_LOG='/var/log/supervisor/changedetector.log'

  _wait_until_expected_count_is_matched "${@}"
}

# NOTE: Change events can start and finish all within < 1 sec,
# Reliably track the completion of a change event by counting events:
function wait_until_change_detection_event_completes() {
  local MATCH_CONTENT='Completed handling of detected change'
  local MATCH_IN_LOG='/var/log/supervisor/changedetector.log'
  
  _wait_until_expected_count_is_matched "${@}"
}

function _get_logs_since_last_change_detection() {
  local CONTAINER_NAME=$1
  local MATCH_IN_FILE='/var/log/supervisor/changedetector.log'
  local MATCH_STRING='Change detected'

  # Read file in reverse, collect lines until match with sed is found,
  # then stop and return these lines back in original order (flipped again through tac):
  docker exec "${CONTAINER_NAME}" bash -c "tac ${MATCH_IN_FILE} | sed '/${MATCH_STRING}/q' | tac"
}
