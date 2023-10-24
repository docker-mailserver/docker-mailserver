load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[ENV] (DMS_VMAIL_UID + DMS_VMAIL_GID) '
CONTAINER_NAME='dms-test_env-change-vmail-id'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env PERMIT_DOCKER=container
    --env DMS_VMAIL_UID=9042
    --env DMS_VMAIL_GID=9042
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container
}

function teardown_file() { _default_teardown ; }

@test 'should successfully deliver mail' {
  _send_email 'email-templates/existing-user1'
  _wait_for_empty_mail_queue_in_container

  # Should be successfully sent (received) by Postfix:
  _run_in_container grep 'to=<user1@localhost.localdomain>' /var/log/mail/mail.log
  assert_success
  assert_output --partial 'status=sent'
  _should_output_number_of_lines 1

  # Verify successful delivery via Dovecot to `/var/mail` account by searching for the subject:
  _repeat_in_container_until_success_or_timeout 20 "${CONTAINER_NAME}" grep -R \
    'Subject: Test Message existing-user1.txt' \
    '/var/mail/localhost.localdomain/user1/new/'
  assert_success
  _should_output_number_of_lines 1
}

# TODO: Migrate to test/helper/common.bash
# This test case is shared with tests.bats, but provides context on errors + some minor edits
# TODO: Could improve in future with keywords from https://github.com/docker-mailserver/docker-mailserver/pull/3550#issuecomment-1738509088
# Potentially via a helper that allows an optional fixed number of errors to be present if they were intentional
@test '/var/log/mail/mail.log is error free' {
  # Postfix: https://serverfault.com/questions/934703/postfix-451-4-3-0-temporary-lookup-failure
  _run_in_container grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure

  # Postfix delivery failure: https://github.com/docker-mailserver/docker-mailserver/issues/230
  _run_in_container grep 'mail system configuration error' /var/log/mail/mail.log
  assert_failure

  # Unknown error source: https://github.com/docker-mailserver/docker-mailserver/pull/85
  _run_in_container grep -i ': error:' /var/log/mail/mail.log
  assert_failure

  # Unknown error source: https://github.com/docker-mailserver/docker-mailserver/pull/320
  _run_in_container grep -i 'not writable' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep -i 'permission denied' /var/log/mail/mail.log
  assert_failure

  # Amavis: https://forum.howtoforge.com/threads/postfix-smtp-error-caused-by-clamav-cant-connect-to-a-unix-socket-var-run-clamav-clamd-ctl.81002/
  _run_in_container grep -i '(!)connect' /var/log/mail/mail.log
  assert_failure

  # Postfix: https://github.com/docker-mailserver/docker-mailserver/pull/2597
  _run_in_container grep -i 'using backwards-compatible default setting' /var/log/mail/mail.log
  assert_failure

  # Postgrey: https://github.com/docker-mailserver/docker-mailserver/pull/612#discussion_r117635774
  _run_in_container grep -i 'connect to 127.0.0.1:10023: Connection refused' /var/log/mail/mail.log
  assert_failure
}

