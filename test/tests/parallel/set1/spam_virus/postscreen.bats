load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Postscreen] '
CONTAINER1_NAME='dms-test_postscreen_enforce'
CONTAINER2_NAME='dms-test_postscreen_sender'

function setup() {
  CONTAINER1_IP=$(_get_container_ip "${CONTAINER1_NAME}")
}

function setup_file() {
  export CONTAINER_NAME

  CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(--env POSTSCREEN_ACTION=enforce)
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  CONTAINER_NAME=${CONTAINER2_NAME}
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(--env PERMIT_DOCKER=host)
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

# Sending mail here is done in a dirty way intentionally.
@test 'should fail send when talking out of turn' {
  CONTAINER_NAME=${CONTAINER1_NAME}
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/emails/nc_raw/postscreen.txt"
  assert_output --partial 'Protocol error'

  _run_in_container cat /var/log/mail/mail.log
  assert_output --partial 'COMMAND PIPELINING'
  assert_output --partial 'DATA without valid RCPT'
}

@test "should successfully pass postscreen and get postfix greeting message (respecting postscreen_greet_wait time)" {
  CONTAINER_NAME=${CONTAINER2_NAME}
  local MAIL_ID=$(_send_email_and_get_id 'postscreen')

  _print_mail_log_for_id "${MAIL_ID}"
  assert_output --partial "stored mail into mailbox 'INBOX'"
}
