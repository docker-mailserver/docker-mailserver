load 'test_helper/common'

# Note if tests fail asserting against `supervisorctl tail changedetector` output,
# use `supervisorctl tail <num bytes> changedetector` instead to increase log output.

function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_changedetector_one)"

  docker run -d --name mail_changedetector_one \
  -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
  -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
  -e DMS_DEBUG=1 \
  -h mail.my-domain.com -t "${NAME}"
  wait_for_finished_setup_in_container mail_changedetector_one

  docker run -d --name mail_changedetector_two \
  -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
  -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
  -e DMS_DEBUG=1 \
  -h mail.my-domain.com -t "${NAME}"
  wait_for_finished_setup_in_container mail_changedetector_two
}

function teardown_file() {
  docker rm -f mail_changedetector_one
  docker rm -f mail_changedetector_two
}

# this test must come first to reliably identify when to run setup_file
@test "first" {
  skip 'Starting testing of changedetector'
}

@test "checking changedetector: servers are ready" {
  wait_for_service mail_changedetector_one changedetector
  wait_for_service mail_changedetector_two changedetector
}

@test "checking changedetector: can detect changes & between two containers using same config" {
  echo "" >> "$(private_config_path mail_changedetector_one)/postfix-accounts.cf"
  sleep 15
  run docker exec mail_changedetector_one /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"
  assert_output --partial "Change detected"
  assert_output --partial "Removed lock"
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"
  assert_output --partial "Change detected"
  assert_output --partial "Removed lock"
}

@test "checking changedetector: lock file found, blocks, and doesn't get prematurely removed" {
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl stop changedetector"
  docker exec mail_changedetector_one /bin/bash -c "touch /tmp/docker-mailserver/check-for-changes.sh.lock"
  echo "" >> "$(private_config_path mail_changedetector_one)/postfix-accounts.cf"
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl start changedetector"
  sleep 15
  run docker exec mail_changedetector_one /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "check-for-changes.sh.lock exists"
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "check-for-changes.sh.lock exists"
  # Ensure starting a new check-for-changes.sh instance (restarting here) doesn't delete the lock
  docker exec mail_changedetector_two /bin/bash -c "rm -f /var/log/supervisor/changedetector.log"
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl restart changedetector"
  sleep 5
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl tail changedetector"
  refute_output --partial "check-for-changes.sh.lock exists"
  refute_output --partial "Removed lock"
}

@test "checking changedetector: lock stale and cleaned up" {
  docker rm -f mail_changedetector_two
  docker exec mail_changedetector_one /bin/bash -c "touch /tmp/docker-mailserver/check-for-changes.sh.lock"
  echo "" >> "$(private_config_path mail_changedetector_one)/postfix-accounts.cf"
  sleep 15
  run docker exec mail_changedetector_one /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "check-for-changes.sh.lock exists"
  sleep 65
  run docker exec mail_changedetector_one /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "Removed stale lock"
}

# this test is only there to reliably mark the end for the teardown_file
@test "last" {
  skip 'Finished testing of changedetector'
}
