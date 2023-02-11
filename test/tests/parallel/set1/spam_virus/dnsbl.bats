load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[DNSBLs] '
CONTAINER1_NAME='dms-test_dnsbl_enabled'
CONTAINER2_NAME='dms-test_dnsbl_disabled'

function setup_file() {
  local CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_DNSBL=1
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  local CONTAINER_NAME=${CONTAINER2_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_DNSBL=0
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

@test "(enabled) Postscreen DNS block lists -> postscreen_dnsbl_action" {
  _run_in_container_explicit "${CONTAINER1_NAME}" postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = enforce'
}

@test "(enabled) Postscreen DNS block lists -> postscreen_dnsbl_sites" {
  _run_in_container_explicit "${CONTAINER1_NAME}" postconf postscreen_dnsbl_sites
  assert_output --regexp '^postscreen_dnsbl_sites = [a-zA-Z0-9]+'
}

@test "(disabled) Postscreen DNS block lists -> postscreen_dnsbl_action" {
  _run_in_container_explicit "${CONTAINER2_NAME}" postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = ignore'
}

@test "(disabled) Postscreen DNS block lists -> postscreen_dnsbl_sites" {
  _run_in_container_explicit "${CONTAINER2_NAME}" postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites ='
}
