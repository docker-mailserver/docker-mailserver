load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

# ENV support for restricting network types that Dovecot and Postfix listen on/
# PRs:
# DOVECOT_INET_PROTOCOLS: https://github.com/docker-mailserver/docker-mailserver/pull/2358
# POSTFIX_INET_PROTOCOLS: https://github.com/docker-mailserver/docker-mailserver/pull/1505

# Docs (upstream):
# https://doc.dovecot.org/settings/core/#core_setting-listen
# https://www.postfix.org/postconf.5.html#inet_protocols

BATS_TEST_NAME_PREFIX='[Network] (ENV *_INET_PROTOCOLS) '
CONTAINER1_NAME='dms-test_inet-protocols_all'
CONTAINER2_NAME='dms-test_inet-protocols_ipv4'
CONTAINER3_NAME='dms-test_inet-protocols_ipv6'

function teardown() { _default_teardown ; }

@test "should configure for dual-stack IP by default" {
  export CONTAINER_NAME=${CONTAINER1_NAME}
  # Unset (default) should be equivalent to 'all':
  local CUSTOM_SETUP_ARGUMENTS=(
    --env DOVECOT_INET_PROTOCOLS=''
    --env POSTFIX_INET_PROTOCOLS=''
  )

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^#listen =' /etc/dovecot/dovecot.conf
  assert_success
  assert_output '#listen = *, ::'

  _run_in_container postconf inet_protocols
  assert_success
  assert_output 'inet_protocols = all'
}

@test "should configure for IPv4-only" {
  export CONTAINER_NAME=${CONTAINER2_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env DOVECOT_INET_PROTOCOLS='ipv4'
    --env POSTFIX_INET_PROTOCOLS='ipv4'
  )

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^listen =' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = *'

  _run_in_container postconf inet_protocols
  assert_success
  assert_output 'inet_protocols = ipv4'
}

@test "should configure for IPv6-only networks" {
  export CONTAINER_NAME=${CONTAINER3_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env DOVECOT_INET_PROTOCOLS='ipv6'
    --env POSTFIX_INET_PROTOCOLS='ipv6'
  )

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container grep '^listen =' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = [::]'

  _run_in_container postconf inet_protocols
  assert_success
  assert_output 'inet_protocols = ipv6'
}
