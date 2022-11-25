load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_NAME_PREFIX='Dovecot protocols:'

@test "${TEST_NAME_PREFIX} dual-stack IP configuration" {
  local CONTAINER_NAME='dms-test-dovecot_protocols_all'
  local CUSTOM_SETUP_ARGUMENTS=(--env DOVECOT_INET_PROTOCOLS=)

  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^#listen = \*, ::' /etc/dovecot/dovecot.conf
  assert_success
  assert_output '#listen = *, ::'

  docker rm -f "${CONTAINER_NAME}"
}

@test "${TEST_NAME_PREFIX} IPv4 configuration" {
  local CONTAINER_NAME='dms-test-dovecot_protocols_ipv4'
  local CUSTOM_SETUP_ARGUMENTS=(--env DOVECOT_INET_PROTOCOLS=ipv4)

  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^listen = \*$' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = *'

  docker rm -f "${CONTAINER_NAME}"
}

@test "${TEST_NAME_PREFIX} IPv6 configuration" {
  local CONTAINER_NAME='dms-test-dovecot_protocols_ipv6'
  local CUSTOM_SETUP_ARGUMENTS=(--env DOVECOT_INET_PROTOCOLS=ipv6)

  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^listen = \[::\]$' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = [::]'

  docker rm -f "${CONTAINER_NAME}"
}
