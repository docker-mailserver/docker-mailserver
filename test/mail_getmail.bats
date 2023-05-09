load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Getmail] '
CONTAINER_NAME='dms-test_getmail'

function setup_file() {
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(--env 'ENABLE_GETMAIL=1')
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test "default configuration exists and is correct" {
  : ;
}
@test "GETMAIL_POLL works as expected" {
  : ;
}
@test "debug-getmail works as expected" {
  : ;
}
