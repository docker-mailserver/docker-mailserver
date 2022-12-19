# ? load the BATS helper
load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

# ? global variable initialization
# ?   to identify the test easily
TEST_NAME_PREFIX='template:'
# ?   must be unique
CONTAINER_NAME='dms-test-template'

# ? test setup

function setup_file() {
  # ? optional setup before container is started

  # ? initialize the test helpers
  init_with_defaults

  # ? add custom arguments supplied to `docker run` here
  local CUSTOM_SETUP_ARGUMENTS=(
    --env LOG_LEVEL=trace
  )

  # ? use a helper to correctly setup the container
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # ? optional setup after the container is started
}

# ? test finalization

function teardown_file() { _default_teardown ; }

# ? actual unit tests

@test "${TEST_NAME_PREFIX} default check" {
  _run_in_container bash -c "true"
  assert_success
}
