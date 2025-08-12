load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[ClamAV + SA] (disabled) '
CONTAINER_NAME='dms-test_clamav-spamassassin_disabled'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_CLAMAV=0
    --env ENABLE_SPAMASSASSIN=0
    --env AMAVIS_LOGLEVEL=2
    --env PERMIT_DOCKER=container
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  _send_email
  _wait_for_empty_mail_queue_in_container
}

function teardown_file() { _default_teardown ; }

@test "ClamAV - Amavis integration should not be active" {
  _service_log_should_not_contain_string 'mail' 'Found secondary av scanner ClamAV-clamscan'
}

@test "SA - Amavis integration should not be active" {
  # Wait until Amavis has finished initializing:
  run _repeat_in_container_until_success_or_timeout 20 "${CONTAINER_NAME}" grep 'Deleting db files  in /var/lib/amavis/db' /var/log/mail/mail.log
  assert_success

  # Amavis module for SA should not be loaded (`SpamControl: scanner SpamAssassin, module Amavis::SpamControl::SpamAssassin`):
  _service_log_should_not_contain_string 'mail' 'scanner SpamAssassin'
}

@test "SA - should not have been called" {
  _service_log_should_not_contain_string 'mail' 'connect to /var/run/clamav/clamd.ctl failed'
}
