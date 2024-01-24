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
# A legitimate mail client should speak SMTP by waiting it's turn, which postscreen defaults enforce (only on port 25)
# https://www.postfix.org/postconf.5.html#postscreen_greet_wait
#
# Use `nc` to send all SMTP commands at once instead (emulate a misbehaving client that should be rejected)
# NOTE: Postscreen only runs on port 25, avoid implicit ports in test methods
@test 'should fail send when talking out of turn' {
  CONTAINER_NAME=${CONTAINER2_NAME} _nc_wrapper 'emails/nc_raw/postscreen.txt' "${CONTAINER1_IP} 25"
  # Expected postscreen log entry:
  assert_output --partial 'Protocol error'

  _run_in_container cat /var/log/mail.log
  assert_output --partial 'COMMAND PIPELINING'
  assert_output --partial 'DATA without valid RCPT'
}

@test "should successfully pass postscreen and get postfix greeting message (respecting postscreen_greet_wait time)" {
  # Configure `send_email()` to send from the mail client container (CONTAINER2_NAME) via ENV override,
  # mail is sent to the DMS server container (CONTAINER1_NAME) via `--server` parameter:
  CONTAINER_NAME=${CONTAINER2_NAME} _send_email --expect-rejection --server "${CONTAINER1_IP}" --port 25 --data 'postscreen.txt'
  # TODO: Use _send_email_with_msgid when proper resolution of domain names is possible:
  # CONTAINER_NAME=${CONTAINER2_NAME} _send_email_with_msgid 'msgid-postscreen' --server "${CONTAINER1_IP}" --data 'postscreen.txt'
  # _print_mail_log_for_msgid 'msgid-postscreen'
  # assert_output --partial "stored mail into mailbox 'INBOX'"

  _service_log_should_contain_string 'mail' 'PASS NEW'
}
