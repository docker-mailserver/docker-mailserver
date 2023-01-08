load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_NAME_PREFIX='Dovecot protocols:'
CONTAINER1_NAME='dms-test_dovecot_protocols_all'
CONTAINER2_NAME='dms-test_dovecot_protocols_ipv4'
CONTAINER3_NAME='dms-test_dovecot_protocols_ipv6'

function teardown() { _default_teardown ; }

@test "${TEST_NAME_PREFIX} dual-stack IP configuration" {
  export CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(--env DOVECOT_INET_PROTOCOLS=)

  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^#listen = \*, ::' /etc/dovecot/dovecot.conf
  assert_success
  assert_output '#listen = *, ::'
}

@test "${TEST_NAME_PREFIX} IPv4 configuration" {
  export CONTAINER_NAME=${CONTAINER2_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(--env DOVECOT_INET_PROTOCOLS=ipv4)

  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^listen = \*$' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = *'
}

@test "${TEST_NAME_PREFIX} IPv6 configuration" {
  export CONTAINER_NAME=${CONTAINER3_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(--env DOVECOT_INET_PROTOCOLS=ipv6)

  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^listen = \[::\]$' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = [::]'
}
