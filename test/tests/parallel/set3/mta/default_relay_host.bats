load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Relay] (ENV) '
CONTAINER_NAME='dms-test_default-relay-host'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env DEFAULT_RELAY_HOST=default.relay.host.invalid:25
    --env PERMIT_DOCKER=host
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test "'DEFAULT_RELAY_HOST' should configure 'main.cf:relayhost'" {
  _run_in_container_bash 'grep -e "^relayhost =" /etc/postfix/main.cf'
  assert_output 'relayhost = default.relay.host.invalid:25'
}
