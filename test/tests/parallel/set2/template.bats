# ? load the BATS helper
load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

# ? global variable initialization
# ?   to identify the test easily
BATS_TEST_NAME_PREFIX='[no-op template] '
# ?   must be unique
CONTAINER_NAME='dms-test_template'

# ? test setup

function setup_file() {
  # ? optional setup before container is started

  # ? initialize the test helpers
  _init_with_defaults

  # ? add custom arguments supplied to `docker run` here
  local CUSTOM_SETUP_ARGUMENTS=(
    --env LOG_LEVEL=trace
  )

  # ? use a helper to correctly setup the container
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # ? optional setup after the container is started
}

# ? test finalization

function teardown_file() { _default_teardown ; }

# ? actual unit tests

@test "default check" {
  _run_in_container_bash "true"
  assert_success
}
