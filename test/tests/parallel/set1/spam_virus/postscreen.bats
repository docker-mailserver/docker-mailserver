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
  local CUSTOM_SETUP_ARGUMENTS=(
    --env POSTSCREEN_ACTION=enforce
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  # A standard DMS instance to send mail from:
  # NOTE: None of DMS is actually used for this (just bash + nc).
  CONTAINER_NAME=${CONTAINER2_NAME}
  _init_with_defaults
  # No need to wait for DMS to be ready for this container:
  _common_container_create
  run docker start "${CONTAINER_NAME}"
  assert_success

  # Set default implicit container fallback for helpers:
  CONTAINER_NAME=${CONTAINER1_NAME}
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

# `POSTSCREEN_ACTION=enforce` (DMS default) should reject delivery with a 550 SMTP reply
# A legitimate mail client should speak SMTP by waiting it's turn,
# Use `nc` to send all SMTP commands at once instead (misbehaving client that should be rejected)
@test 'should fail send when talking out of turn' {
  CONTAINER_NAME=${CONTAINER2_NAME} _nc_wrapper 'emails/nc_raw/postscreen' "${CONTAINER1_IP} 25"
  # Expected postscreen log entry:
  assert_output --partial 'Protocol error'

  _run_in_container cat /var/log/mail.log
  assert_output --partial 'COMMAND PIPELINING'
  assert_output --partial 'DATA without valid RCPT'
}

@test "should successfully pass postscreen and get postfix greeting message (respecting postscreen_greet_wait time)" {
  # Send from mail client container (CONTAINER2_NAME) to DMS server container (CONTAINER1_NAME):
  CONTAINER_NAME=${CONTAINER2_NAME} _send_email --server "${CONTAINER1_IP}" --data 'postscreen'
  assert_success

    # TODO: Implement support for separate client and server containers:
  # local MAIL_ID=$(_send_email_and_get_id --data 'postscreen')
  # _print_mail_log_for_id "${MAIL_ID}"
  # assert_output --partial "stored mail into mailbox 'INBOX'"

  _run_in_container cat /var/log/mail.log
  assert_output --partial 'PASS NEW'
}
