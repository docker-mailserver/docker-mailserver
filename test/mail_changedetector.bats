load 'test_helper/common'

# Note if tests fail asserting against `supervisorctl tail changedetector` output,
# use `supervisorctl tail -<num bytes> changedetector` instead to increase log output.
# Default `<num bytes>` appears to be around 1500.

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
  echo "" >> "$(private_config_path mail_changedetector_one)/postfix-accounts.cf"
  sleep 25

  run docker exec mail_changedetector_one /bin/bash -c "supervisorctl tail -3000 changedetector"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"
  assert_output --partial "Change detected"
  assert_output --partial "Removed lock"

  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl tail -3000 changedetector"
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
  assert_output --partial "another execution of 'check-for-changes.sh' is happening"
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "another execution of 'check-for-changes.sh' is happening"

  # Ensure starting a new check-for-changes.sh instance (restarting here) doesn't delete the lock
  docker exec mail_changedetector_two /bin/bash -c "rm -f /var/log/supervisor/changedetector.log"
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl restart changedetector"
  sleep 5
  run docker exec mail_changedetector_two /bin/bash -c "supervisorctl tail changedetector"
  refute_output --partial "another execution of 'check-for-changes.sh' is happening"
  refute_output --partial "Removed lock"
}

@test "checking changedetector: lock stale and cleaned up" {
  docker rm -f mail_changedetector_two
  docker exec mail_changedetector_one /bin/bash -c "touch /tmp/docker-mailserver/check-for-changes.sh.lock"
  echo "" >> "$(private_config_path mail_changedetector_one)/postfix-accounts.cf"
  sleep 15

  run docker exec mail_changedetector_one /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "another execution of 'check-for-changes.sh' is happening"
  sleep 65

  run docker exec mail_changedetector_one /bin/bash -c "supervisorctl tail -3000 changedetector"
  assert_output --partial "removing stale lock file"
}
