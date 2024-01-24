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
  _nc_wrapper 'auth/pop3-auth.txt' '-w 1 0.0.0.0 110'
  assert_success
}

@test 'added user authentication works' {
  _nc_wrapper 'auth/added-pop3-auth.txt' '-w 1 0.0.0.0 110'
  assert_success
}

# TODO: Remove in favor of a common helper method, as described in vmail-id.bats equivalent test-case
@test 'Mail log is error free' {
  _service_log_should_not_contain_string 'mail' 'non-null host address bits in'
  _service_log_should_not_contain_string 'mail' ': Error:'
}

@test '(Manage Sieve) disabled per default' {
  _run_in_container nc -z 0.0.0.0 4190
  assert_failure
}
