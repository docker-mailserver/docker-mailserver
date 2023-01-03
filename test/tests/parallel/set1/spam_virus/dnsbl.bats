load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_NAME_PREFIX='DNSBLs:'

CONTAINER1_NAME='dms-test_dnsbl_enabled'
CONTAINER2_NAME='dms-test_dnsbl_disabled'

function setup_file() {
  local CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_DNSBL=1
  )
  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  wait_for_smtp_port_in_container "${CONTAINER_NAME}"

  local CONTAINER_NAME=${CONTAINER2_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_DNSBL=0
  )
  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  wait_for_smtp_port_in_container "${CONTAINER_NAME}"
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

# ENABLE_DNSBL=1
@test "${TEST_NAME_PREFIX} (enabled) Postfix DNS block list zen.spamhaus.org" {
  run docker exec "${CONTAINER1_NAME}" postconf smtpd_recipient_restrictions
  assert_output --partial 'reject_rbl_client zen.spamhaus.org'
}

@test "${TEST_NAME_PREFIX} (enabled) Postscreen DNS block lists -> postscreen_dnsbl_action" {
  run docker exec "${CONTAINER1_NAME}" postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = enforce'
}

@test "${TEST_NAME_PREFIX} (enabled) Postscreen DNS block lists -> postscreen_dnsbl_sites" {
  run docker exec "${CONTAINER1_NAME}" postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites = zen.spamhaus.org=127.0.0.[2..11]*3 bl.mailspike.net=127.0.0.[2;14;13;12;11;10] b.barracudacentral.org*2 bl.spameatingmonkey.net=127.0.0.2 dnsbl.sorbs.net psbl.surriel.com list.dnswl.org=127.0.[0..255].0*-2 list.dnswl.org=127.0.[0..255].1*-3 list.dnswl.org=127.0.[0..255].[2..3]*-4'
}

# ENABLE_DNSBL=0
@test "${TEST_NAME_PREFIX} (disabled) Postfix DNS block list zen.spamhaus.org" {
  run docker exec "${CONTAINER2_NAME}" postconf smtpd_recipient_restrictions
  refute_output --partial 'reject_rbl_client zen.spamhaus.org'
}

@test "${TEST_NAME_PREFIX} (disabled) Postscreen DNS block lists -> postscreen_dnsbl_action" {
  run docker exec "${CONTAINER2_NAME}" postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = ignore'
}

@test "${TEST_NAME_PREFIX} (disabled) Postscreen DNS block lists -> postscreen_dnsbl_sites" {
  run docker exec "${CONTAINER2_NAME}" postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites ='
}
