load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[POP3] '
CONTAINER_NAME='dms-test_pop3'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_POP3=1
    --env PERMIT_DOCKER=container
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test 'server is ready' {
  _run_in_container nc -w 1 0.0.0.0 110
  assert_success
  assert_output --partial '+OK'
}

@test 'authentication works' {
  _run_in_container_bash 'nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/pop3-auth.txt'
  assert_success
}

@test 'added user authentication works' {
  _run_in_container_bash 'nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/added-pop3-auth.txt'
  assert_success
}

@test '/var/log/mail/mail.log is error-free' {
  _run_in_container grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep ': error:' /var/log/mail/mail.log
  assert_failure
}

@test '(Manage Sieve) disabled per default' {
  _run_in_container nc -z 0.0.0.0 4190
  assert_failure
}
