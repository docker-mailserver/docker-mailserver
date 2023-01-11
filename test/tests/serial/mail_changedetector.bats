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
  sleep 25

  run _get_logs_since_last_change_detection mail_changedetector_one
  _assert_has_standard_change_event_logs

  run _get_logs_since_last_change_detection mail_changedetector_two
  _assert_has_standard_change_event_logs
}

@test "checking changedetector: lock file found, blocks, and doesn't get prematurely removed" {
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl stop changedetector"
  docker exec mail_changedetector_one /bin/bash -c "touch /tmp/docker-mailserver/check-for-changes.sh.lock"
  _create_change_event
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl start changedetector"
  sleep 15

  run _get_logs_since_last_change_detection mail_changedetector_one
  _assert_foreign_lock_exists

  run _get_logs_since_last_change_detection mail_changedetector_two
  _assert_foreign_lock_exists

  # Ensure starting a new check-for-changes.sh instance (restarting here) doesn't delete the lock
  docker exec mail_changedetector_two /bin/bash -c "rm -f /var/log/supervisor/changedetector.log"
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl restart changedetector"
  sleep 5
  run _get_logs_since_last_change_detection mail_changedetector_two
  _assert_no_lock_actions_performed
}

@test "checking changedetector: lock stale and cleaned up" {
  # Avoid a race condition (to remove the lock file) by removing the 2nd container:
  docker rm -f mail_changedetector_two
  # Make the previously created lock file become stale:
  docker exec mail_changedetector_one touch -d '60 seconds ago' /tmp/docker-mailserver/check-for-changes.sh.lock

  # Previous change event should now be processed (stale lock is detected and removed):
  wait_until_change_detection_event_completes mail_changedetector_one

  run _get_logs_since_last_change_detection mail_changedetector_one
  assert_output --partial 'Lock file older than 1 minute - removing stale lock file'
  _assert_has_standard_change_event_logs
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

function _create_change_event() {
  echo "" >> "$(private_config_path mail_changedetector_one)/postfix-accounts.cf"
}

function _get_logs_since_last_change_detection() {
  local CONTAINER_NAME=$1
  local MATCH_IN_FILE='/var/log/supervisor/changedetector.log'
  local MATCH_STRING='Change detected'

  docker exec "${CONTAINER_NAME}" bash -c "tac ${MATCH_IN_FILE} | sed '/${MATCH_STRING}/q' | tac"
}
