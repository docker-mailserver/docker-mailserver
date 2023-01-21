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

# ENABLE_DNSBL=1
@test "(enabled) Postfix DNS block list zen.spamhaus.org" {
  _run_in_container_explicit "${CONTAINER1_NAME}" postconf smtpd_recipient_restrictions
  assert_output --partial 'reject_rbl_client zen.spamhaus.org'
}

@test "(enabled) Postscreen DNS block lists -> postscreen_dnsbl_action" {
  _run_in_container_explicit "${CONTAINER1_NAME}" postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = enforce'
}

@test "(enabled) Postscreen DNS block lists -> postscreen_dnsbl_sites" {
  _run_in_container_explicit "${CONTAINER1_NAME}" postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites = zen.spamhaus.org=127.0.0.[2..11]*3 bl.mailspike.net=127.0.0.[2;14;13;12;11;10] b.barracudacentral.org*2 bl.spameatingmonkey.net=127.0.0.2 dnsbl.sorbs.net psbl.surriel.com list.dnswl.org=127.0.[0..255].0*-2 list.dnswl.org=127.0.[0..255].1*-3 list.dnswl.org=127.0.[0..255].[2..3]*-4'
}

# ENABLE_DNSBL=0
@test "(disabled) Postfix DNS block list zen.spamhaus.org" {
  _run_in_container_explicit "${CONTAINER2_NAME}" postconf smtpd_recipient_restrictions
  refute_output --partial 'reject_rbl_client zen.spamhaus.org'
}

@test "(disabled) Postscreen DNS block lists -> postscreen_dnsbl_action" {
  _run_in_container_explicit "${CONTAINER2_NAME}" postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = ignore'
}

@test "(disabled) Postscreen DNS block lists -> postscreen_dnsbl_sites" {
  _run_in_container_explicit "${CONTAINER2_NAME}" postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites ='
}
