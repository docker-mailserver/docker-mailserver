load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Timezone] '
CONTAINER_NAME='dms-test_timezone'

function setup_file() {
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(--env TZ='Asia/Jakarta')
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test "setting the time with TZ works correctly" {
  _run_in_container cat /etc/timezone
  assert_success
  assert_output 'Asia/Jakarta'

  _run_in_container date '+%Z'
  assert_success
  assert_output 'WIB'
}
