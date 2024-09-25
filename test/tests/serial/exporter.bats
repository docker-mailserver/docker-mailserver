load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[EXPORTER] '
CONTAINER_NAME='dms-test_exporter'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_EXPORTER=1
    --env PERMIT_DOCKER=container
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _wait_for_service exporter
}

function teardown_file() { _default_teardown ; }

@test 'server is ready' {
  _run_in_container nc -w 1 0.0.0.0 9154
    assert_success
}

@test 'metrics are available' {
  _run_in_container curl -s http://0.0.0.0:9154/metrics
    assert_success
    assert_output --partial 'postfix_qmgr_messages_inserted_receipients_sum'
}
