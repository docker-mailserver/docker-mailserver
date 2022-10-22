load 'test_helper/common'

CONTAINER="mail_dnsbl_enabled"
CONTAINER2="mail_dnsbl_disabled"

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER}")

  docker run --rm -d --name "${CONTAINER}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -e ENABLE_DNSBL=1 \
    -h mail.my-domain.com \
    -t "${NAME}"

  docker run --rm -d --name "${CONTAINER2}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -e ENABLE_DNSBL=0 \
    -h mail.my-domain.com \
    -t "${NAME}"

  wait_for_smtp_port_in_container "${CONTAINER}"
  wait_for_smtp_port_in_container "${CONTAINER2}"
}

# ENABLE_DNSBL=1
@test "checking enabled postfix DNS block list zen.spamhaus.org" {
  run docker exec "${CONTAINER}" postconf smtpd_recipient_restrictions
  assert_output --partial 'reject_rbl_client zen.spamhaus.org'
}

@test "checking enabled postscreen DNS block lists --> postscreen_dnsbl_action" {
  run docker exec "${CONTAINER}" postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = enforce'
}

@test "checking enabled postscreen DNS block lists --> postscreen_dnsbl_sites" {
  run docker exec "${CONTAINER}" postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites = zen.spamhaus.org*3 bl.mailspike.net b.barracudacentral.org*2 bl.spameatingmonkey.net dnsbl.sorbs.net psbl.surriel.com list.dnswl.org=127.0.[0..255].0*-2 list.dnswl.org=127.0.[0..255].1*-3 list.dnswl.org=127.0.[0..255].[2..3]*-4'
}

# ENABLE_DNSBL=0
@test "checking disabled postfix DNS block list zen.spamhaus.org" {
  run docker exec "${CONTAINER2}" postconf smtpd_recipient_restrictions
  refute_output --partial 'reject_rbl_client zen.spamhaus.org'
}

@test "checking disabled postscreen DNS block lists --> postscreen_dnsbl_action" {
  run docker exec "${CONTAINER2}" postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = ignore'
}

@test "checking disabled postscreen DNS block lists --> postscreen_dnsbl_sites" {
  run docker exec "${CONTAINER2}" postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites ='
}

# cleanup
function teardown_file() {
    docker rm -f "${CONTAINER}" "${CONTAINER2}"
}
