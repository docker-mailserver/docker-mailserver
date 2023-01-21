load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/change-detection"
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
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER2_NAME}
  # NOTE: No `init_with_defaults` used here,
  # Intentionally sharing previous containers config instead.
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Set default implicit container fallback for helpers:
  CONTAINER_NAME=${CONTAINER1_NAME}
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

@test "changedetector service is ready" {
  _wait_for_service changedetector "${CONTAINER1_NAME}"
  _wait_for_service changedetector "${CONTAINER2_NAME}"
}

# NOTE: Non-deterministic behaviour - One container will perform change detection before the other.
# Depending on the timing of the other container checking for a lock file, the lock may no longer be
# present, avoiding the 5 second delay. The first container to create a lock is not deterministic either.
# NOTE: Change detection at this point typically occurs at 2 or 4 seconds since the service was up,
# thus expect 2-8 seconds to complete.
@test "should detect and process changes (in both containers with shared config)" {
  _create_change_event

  _should_perform_standard_change_event "${CONTAINER1_NAME}"
  _should_perform_standard_change_event "${CONTAINER2_NAME}"
}

# Both containers should acknowledge the foreign lock file added,
# blocking an attempt to process the pending change event detected.
@test "should find existing lock file and block processing changes (without removing lock)" {
  _prepare_blocking_lock_test

  # Wait until the 2nd change event attempts to process:
  _should_block_change_event_from_processing 2 "${CONTAINER1_NAME}"
  # NOTE: Although the service is restarted, a change detection should still occur (previous checksum still exists):
  _should_block_change_event_from_processing 1 "${CONTAINER2_NAME}"
}

@test "should remove lock file when stale" {
  # Avoid a race condition (to remove the lock file) by removing the 2nd container:
  docker rm -f "${CONTAINER2_NAME}"
  # Make the previously created lock file become stale:
  docker exec "${CONTAINER1_NAME}" touch -d '60 seconds ago' /tmp/docker-mailserver/check-for-changes.sh.lock

  # A 2nd change event should complete (or may already have if quick enough?):
  _wait_until_change_detection_event_completes 2 "${CONTAINER1_NAME}"

  # Should have removed the stale lock file, then handle the change event:
  run _get_logs_since_last_change_detection "${CONTAINER1_NAME}"
  assert_output --partial 'Lock file older than 1 minute - removing stale lock file'
  _assert_has_standard_change_event_logs
}

function _should_perform_standard_change_event() {
  local CONTAINER_NAME=${1}

  # Wait for change detection event to start and complete processing:
  # NOTE: An explicit count is provided as the 2nd container may have already completed processing.
  _wait_until_change_detection_event_completes 1

  # Container should have created it's own lock file,
  # and later removed it when finished processing:
  run _get_logs_since_last_change_detection
  _assert_has_standard_change_event_logs
}

function _should_block_change_event_from_processing() {
  local EXPECTED_COUNT=${1}
  local CONTAINER_NAME=${2}

  # Once the next change event has started, the processing blocked log ('another execution') should be present:
  _wait_until_change_detection_event_begins "${EXPECTED_COUNT}"

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
  local CONTAINER_NAME=${CONTAINER2_NAME}
  # Temporarily disable the Container2 changedetector service:
  _exec_in_container_bash 'supervisorctl stop changedetector'
  _exec_in_container_bash 'rm -f /var/log/supervisor/changedetector.log'

  # Create a foreign lock file to prevent change processing (in both containers):
  _exec_in_container_explicit "${CONTAINER1_NAME}" /bin/bash -c 'touch /tmp/docker-mailserver/check-for-changes.sh.lock'
  # Create a new change to detect (that the foreign lock should prevent from processing):
  _create_change_event

  # Restore Container2 changedetector service:
  # NOTE: The last known checksum is retained in Container2,
  #       It will be compared to and start a change event.
  _exec_in_container_bash 'supervisorctl start changedetector'
}

function _create_change_event() {
  echo '' >>"${TEST_TMP_CONFIG}/postfix-accounts.cf"
}
