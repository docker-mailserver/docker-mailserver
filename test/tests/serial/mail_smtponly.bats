load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[SMTP-Only] '
CONTAINER_NAME='dms-test_env-smtp-only'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env SMTP_ONLY=1
    --env PERMIT_DOCKER=network
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _wait_for_smtp_port_in_container
}

function teardown_file() { _default_teardown ; }

@test "Dovecot quota absent in postconf" {
  _run_in_container postconf
  assert_success
  refute_output --partial "check_policy_service inet:localhost:65265'"
}

# TODO: needs complete rework when proper DNS container is running for tests
@test "sending mail should work" {
  skip 'TODO: This test is absolutely broken and needs reworking!'

  assert_success


  # it looks as if someone tries to send mail to another domain outside of DMS
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/smtp-only.txt"
  assert_success
  _wait_for_empty_mail_queue_in_container

  # this seemingly succeeds, but looking at the logs, it doesn't
  _run_in_container_bash 'grep -cE "to=<user2\@external.tld>.*status\=sent" /var/log/mail/mail.log'
  # this is absolutely useless! `grep -c` count 0 but also returns 0; the mail was never properly sent!
  [[ ${status} -ge 0 ]]
}
