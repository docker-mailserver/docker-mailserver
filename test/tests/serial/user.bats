load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[User] '
CONTAINER_NAME='dms-test_User_change_uid'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_POP3=1
    --env PERMIT_DOCKER=container
    --env UID_DOCKER=10000
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container users
}

function teardown_file() { _default_teardown ; }
@test 'server is ready' {
  _run_in_container nc -w 1 0.0.0.0 110
  assert_success
  assert_output --partial '+OK'
}


@test 'authentication works' {
  _send_email 'auth/pop3-auth' '-w 1 0.0.0.0 110'
}

@test 'added user authentication works' {
  _send_email 'auth/added-pop3-auth' '-w 1 0.0.0.0 110'
}

@test '/var/log/mail/mail.log is error-free' {
  _run_in_container grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep ': error:' /var/log/mail/mail.log
  assert_failure
}

