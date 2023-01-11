load "${REPOSITORY_ROOT}/test/test_helper/common"

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_changedetector_one)

  docker run -d --name mail_changedetector_one \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e LOG_LEVEL=trace \
    -h mail.my-domain.com -t "${NAME}"

  docker run -d --name mail_changedetector_two \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e LOG_LEVEL=trace \
    -h mail.my-domain.com -t "${NAME}"

  wait_for_finished_setup_in_container mail_changedetector_one
  wait_for_finished_setup_in_container mail_changedetector_two
}

function teardown_file() {
  docker rm -f mail_changedetector_one
  docker rm -f mail_changedetector_two
}

@test "checking changedetector: servers are ready" {
  wait_for_service mail_changedetector_one changedetector
  wait_for_service mail_changedetector_two changedetector
}

@test "checking changedetector: can detect changes & between two containers using same config" {
  _create_change_event

  _should_perform_standard_change_event mail_changedetector_one
  _should_perform_standard_change_event mail_changedetector_two
}

@test "checking changedetector: lock file found, blocks, and doesn't get prematurely removed" {
  _prepare_blocking_lock_test

  # Wait until the 2nd change event attempts to process:
  _should_block_change_event_from_processing mail_changedetector_one 2
  # NOTE: Although the service is restarted, a change detection should still occur (previous checksum still exists):
  _should_block_change_event_from_processing mail_changedetector_two 1
}

@test "checking changedetector: lock stale and cleaned up" {
  # Avoid a race condition (to remove the lock file) by removing the 2nd container:
  docker rm -f mail_changedetector_two
  # Make the previously created lock file become stale:
  docker exec mail_changedetector_one touch -d '60 seconds ago' /tmp/docker-mailserver/check-for-changes.sh.lock

  # A 2nd change event should complete (or may already have if quick enough?):
  wait_until_change_detection_event_completes mail_changedetector_one 2

  # Should have removed the stale lock file, then handle the change event:
  run _get_logs_since_last_change_detection mail_changedetector_one
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
  docker exec mail_changedetector_two bash -c "supervisorctl stop changedetector"
  docker exec mail_changedetector_two bash -c 'rm -f /var/log/supervisor/changedetector.log'

  # Create a foreign lock file to prevent change processing (in both containers):
  docker exec mail_changedetector_one bash -c "touch /tmp/docker-mailserver/check-for-changes.sh.lock"
  # Create a new change to detect (that the foreign lock should prevent from processing):
  _create_change_event

  # Restore Container2 changedetector service:
  # NOTE: The last known checksum is retained in Container2,
  #       It will be compared to and start a change event.
  docker exec mail_changedetector_two bash -c "supervisorctl start changedetector"
}

function _create_change_event() {
  echo "" >> "$(private_config_path mail_changedetector_one)/postfix-accounts.cf"
}

function _get_logs_since_last_change_detection() {
  local CONTAINER_NAME=$1
  local MATCH_IN_FILE='/var/log/supervisor/changedetector.log'
  local MATCH_STRING='Change detected'

  docker exec "${CONTAINER_NAME}" bash -c "tac ${MATCH_IN_FILE} | sed '/${MATCH_STRING}/q' | tac"
}
