load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Change Detection] '

CONTAINER1_NAME='dms-test_changedetector_one'
CONTAINER2_NAME='dms-test_changedetector_two'

function setup_file() {
  export CONTAINER_NAME

  local CUSTOM_SETUP_ARGUMENTS=(
    --env LOG_LEVEL=trace
  )

  CONTAINER_NAME=${CONTAINER1_NAME}
  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER2_NAME}
  # NOTE: No `init_with_defaults` used here,
  # Intentionally sharing previous containers config instead.
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Set default implicit container fallback for helpers:
  CONTAINER_NAME=${CONTAINER1_NAME}
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

@test "changedetector service is ready" {
  wait_for_service "${CONTAINER1_NAME}" changedetector
  wait_for_service "${CONTAINER2_NAME}" changedetector
}

@test "should detect and process changes (in both containers with shared config)" {
  _create_change_event

  _should_perform_standard_change_event "${CONTAINER1_NAME}"
  _should_perform_standard_change_event "${CONTAINER2_NAME}"
}

@test "should find existing lock file and block processing changes (without removing lock)" {
  _prepare_blocking_lock_test

  # Wait until the 2nd change event attempts to process:
  _should_block_change_event_from_processing "${CONTAINER1_NAME}" 2
  # NOTE: Although the service is restarted, a change detection should still occur (previous checksum still exists):
  _should_block_change_event_from_processing "${CONTAINER2_NAME}" 1
}

@test "should remove lock file when stale" {
  # Avoid a race condition (to remove the lock file) by removing the 2nd container:
  docker rm -f "${CONTAINER2_NAME}"
  # Make the previously created lock file become stale:
  docker exec "${CONTAINER1_NAME}" touch -d '60 seconds ago' /tmp/docker-mailserver/check-for-changes.sh.lock

  # A 2nd change event should complete (or may already have if quick enough?):
  wait_until_change_detection_event_completes "${CONTAINER1_NAME}" 2

  # Should have removed the stale lock file, then handle the change event:
  run _get_logs_since_last_change_detection "${CONTAINER1_NAME}"
  assert_output --partial 'Lock file older than 1 minute - removing stale lock file'
  _assert_has_standard_change_event_logs
}

function _should_perform_standard_change_event() {
  local CONTAINER_NAME=$1

  # Wait for change detection event to start and complete processing:
  # NOTE: An explicit count is provided as the 2nd container may have already completed processing.
  wait_until_change_detection_event_completes "${CONTAINER_NAME}" 1

  # Container should have created it's own lock file,
  # and later removed it when finished processing:
  run _get_logs_since_last_change_detection "${CONTAINER_NAME}"
  _assert_has_standard_change_event_logs
}

function _should_block_change_event_from_processing() {
  local CONTAINER_NAME=$1
  local EXPECTED_COUNT=$2

  # Once the next change event has started, the processing blocked log ('another execution') should be present:
  wait_until_change_detection_event_begins "${CONTAINER_NAME}" "${EXPECTED_COUNT}"

  run _get_logs_since_last_change_detection "${CONTAINER_NAME}"
  _assert_foreign_lock_exists
  # This additionally verifies that the change event processing is incomplete (blocked):
  _assert_no_lock_actions_performed
}

function _assert_has_standard_change_event_logs() {
  assert_output --partial "Creating lock '/tmp/docker-mailserver/check-for-changes.sh.lock'"
  assert_output --partial 'Reloading services due to detected changes'
  assert_output --partial 'Removed lock'
  assert_output --partial 'Completed handling of detected change'
}

function _assert_foreign_lock_exists() {
  assert_output --partial "Lock file '/tmp/docker-mailserver/check-for-changes.sh.lock' exists"
  assert_output --partial "- another execution of 'check-for-changes.sh' is happening - trying again shortly"
}

function _assert_no_lock_actions_performed() {
  refute_output --partial 'Lock file older than 1 minute - removing stale lock file'
  refute_output --partial "Creating lock '/tmp/docker-mailserver/check-for-changes.sh.lock'"
  refute_output --partial 'Removed lock'
}

function _prepare_blocking_lock_test {
  # Temporarily disable the Container2 changedetector service:
  docker exec "${CONTAINER2_NAME}" bash -c 'supervisorctl stop changedetector'
  docker exec "${CONTAINER2_NAME}" bash -c 'rm -f /var/log/supervisor/changedetector.log'

  # Create a foreign lock file to prevent change processing (in both containers):
  docker exec "${CONTAINER1_NAME}" bash -c 'touch /tmp/docker-mailserver/check-for-changes.sh.lock'
  # Create a new change to detect (that the foreign lock should prevent from processing):
  _create_change_event

  # Restore Container2 changedetector service:
  # NOTE: The last known checksum is retained in Container2,
  #       It will be compared to and start a change event.
  docker exec "${CONTAINER2_NAME}" bash -c 'supervisorctl start changedetector'
}

function _create_change_event() {
  echo '' >> "${TEST_TMP_CONFIG}/postfix-accounts.cf"
}

function _get_logs_since_last_change_detection() {
  local CONTAINER_NAME=$1
  local MATCH_IN_FILE='/var/log/supervisor/changedetector.log'
  local MATCH_STRING='Change detected'

  docker exec "${CONTAINER_NAME}" bash -c "tac ${MATCH_IN_FILE} | sed '/${MATCH_STRING}/q' | tac"
}
