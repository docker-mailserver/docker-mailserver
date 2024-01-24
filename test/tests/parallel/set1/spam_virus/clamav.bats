load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[ClamAV] '
CONTAINER_NAME='dms-test_clamav'

function setup_file() {
  _init_with_defaults

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

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # wait for ClamAV to be fully setup or we will get errors on the log
  _repeat_in_container_until_success_or_timeout 60 "${CONTAINER_NAME}" test -e /var/run/clamav/clamd.ctl

  _wait_for_service postfix
  _wait_for_smtp_port_in_container
  _send_email --from 'virus@external.tld' --data 'amavis/virus.txt'
  _wait_for_empty_mail_queue_in_container
}

function teardown_file() { _default_teardown ; }

@test 'log files exist at /var/log/mail directory' {
  _run_in_container_bash "ls -1 /var/log/mail/ | grep -c -E 'clamav|freshclam|mail.log'"
  assert_success
  assert_output 3
}

@test 'should be identified by Amavis' {
  _service_log_should_contain_string 'mail' 'Found secondary av scanner ClamAV-clamscan'
}

@test 'freshclam cron is enabled' {
  _run_in_container_bash "grep '/usr/bin/freshclam' -r /etc/cron.d"
  assert_success
}

@test 'env CLAMAV_MESSAGE_SIZE_LIMIT is set correctly' {
  _run_in_container grep -q '^MaxFileSize 30M$' /etc/clamav/clamd.conf
  assert_success
}

@test 'rejects virus' {
  _service_log_should_contain_string 'mail' 'Blocked INFECTED'
  assert_output --partial '<virus@external.tld> -> <user1@localhost.localdomain>'
}
