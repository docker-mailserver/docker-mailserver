load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[ClamAV + SA] (disabled) '
CONTAINER_NAME='dms-test_clamav-spamassasin_disabled'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_CLAMAV=0
    --env ENABLE_SPAMASSASSIN=0
    --env AMAVIS_LOGLEVEL=2
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success
  _wait_for_empty_mail_queue_in_container
}

function teardown_file() { _default_teardown ; }

@test "ClamAV - Amavis integration should not be active" {
  _run_in_container grep -i 'Found secondary av scanner ClamAV-clamscan' /var/log/mail/mail.log
  assert_failure
}

@test "SA - Amavis integration should not be active" {
  _run_in_container_bash "grep -i 'ANTI-SPAM-SA code' /var/log/mail/mail.log | grep 'NOT loaded'"
  assert_success
}

@test "SA - should not have been called" {
  _run_in_container grep -i 'connect to /var/run/clamav/clamd.ctl failed' /var/log/mail/mail.log
  assert_failure
}
