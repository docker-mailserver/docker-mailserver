load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_NAME_PREFIX='ClamAV:'
CONTAINER_NAME='dms-test-clamav'

function setup_file() {
  init_with_defaults

  # Comment for maintainers about `PERMIT_DOCKER=host`:
  # https://github.com/docker-mailserver/docker-mailserver/pull/2815/files#r991087509
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_CLAMAV=1
    --env ENABLE_AMAVIS=1
    --env PERMIT_DOCKER=host
    --env AMAVIS_LOGLEVEL=2
    --env CLAMAV_MESSAGE_SIZE_LIMIT=30M
    --env LOG_LEVEL=trace
  )

  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # wait for ClamAV to be fully setup or we will get errors on the log
  repeat_in_container_until_success_or_timeout 60 "${CONTAINER_NAME}" test -e /var/run/clamav/clamd.ctl

  wait_for_service "${CONTAINER_NAME}" postfix
  wait_for_smtp_port_in_container "${CONTAINER_NAME}"

  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-virus.txt"
  assert_success

  wait_for_empty_mail_queue_in_container "${CONTAINER_NAME}"
}

function teardown_file() { _default_teardown ; }

@test "${TEST_NAME_PREFIX} process clamd is running" {
  _run_in_container bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_success
}

@test "${TEST_NAME_PREFIX} log files exist at /var/log/mail directory" {
  _run_in_container bash -c "ls -1 /var/log/mail/ | grep -E 'clamav|freshclam|mail.log' | wc -l"
  assert_success
  assert_output 3
}

@test "${TEST_NAME_PREFIX} should be identified by Amavis" {
  _run_in_container grep -i 'Found secondary av scanner ClamAV-clamscan' /var/log/mail/mail.log
  assert_success
}

@test "${TEST_NAME_PREFIX} freshclam cron is enabled" {
  _run_in_container bash -c "grep '/usr/bin/freshclam' -r /etc/cron.d"
  assert_success
}

@test "${TEST_NAME_PREFIX} env CLAMAV_MESSAGE_SIZE_LIMIT is set correctly" {
  _run_in_container grep -q '^MaxFileSize 30M$' /etc/clamav/clamd.conf
  assert_success
}

@test "${TEST_NAME_PREFIX} rejects virus" {
  _run_in_container bash -c "grep 'Blocked INFECTED' /var/log/mail/mail.log | grep '<virus@external.tld> -> <user1@localhost.localdomain>'"
  assert_success
}

@test "${TEST_NAME_PREFIX} process clamd restarts when killed" {
  _run_in_container bash -c "pkill clamd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_success
}
