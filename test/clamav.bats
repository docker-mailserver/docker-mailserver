load 'test_helper/common'

TEST_NAME_PREFIX='checking ClamAV: '
CONTAINER_NAME='dms-test-clamav'

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  docker run --rm --detach --tty \
    --name "${CONTAINER_NAME}" \
    --volume "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
    --env ENABLE_AMAVIS=1 \
    --env AMAVIS_LOGLEVEL=2 \
    --env ENABLE_CLAMAV=1 \
    --env ENABLE_UPDATE_CHECK=0 \
    --env ENABLE_SPAMASSASSIN=0 \
    --env ENABLE_FAIL2BAN=0 \
    --env CLAMAV_MESSAGE_SIZE_LIMIT=30M \
    --env LOG_LEVEL=debug \
    --hostname mail.my-domain.com \
    "${IMAGE_NAME}"

  wait_for_finished_setup_in_container "${CONTAINER_NAME}"

  # wait for ClamAV to be fully setup or we will get errors on the log
  repeat_in_container_until_success_or_timeout 60 "${CONTAINER_NAME}" test -e /var/run/clamav/clamd.ctl
}

function teardown_file() {
  docker rm -f "${CONTAINER_NAME}"
}

@test "${TEST_NAME_PREFIX}checking process clamd is running" {
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_success
}

@test "${TEST_NAME_PREFIX}checking logs - mail related logs should be located in a subdirectory" {
  run docker exec "${CONTAINER_NAME}" /bin/sh -c "ls -1 /var/log/mail/ | grep -E 'clamav|freshclam|mail.log'| wc -l"
  assert_success
  assert_output 3
}

@test "${TEST_NAME_PREFIX}ClamAV should be listed in Amavis" {
  run docker exec "${CONTAINER_NAME}" grep -i 'Found secondary av scanner ClamAV-clamscan' /var/log/mail/mail.log
  assert_success
}

@test "${TEST_NAME_PREFIX}checking CLAMAV_MESSAGE_SIZE_LIMIT is set correctly" {
  run docker exec "${CONTAINER_NAME}" grep -q '^MaxFileSize 30M$' /etc/clamav/clamd.conf
  assert_success
}

@test "${TEST_NAME_PREFIX}checking restart of clamd process" {
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "pkill clamd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_success
}
