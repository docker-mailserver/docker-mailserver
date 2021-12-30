load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function setup_file() {
  local PRIVATE_CONFIG CONTAINER CONTAINER2
  PRIVATE_CONFIG="$(duplicate_config_for_container . "${CONTAINER}")"
  CONTAINER="mail_dnsbl_enabled"
  CONTAINER2="mail_dnsbl_disabled"

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

@test "first" {
  skip 'only used to call setup_file from setup'
}

# ENABLE_DNSBL=1
@test "checking enabled postfix DNS block list zen.spamhaus.org" {
  run docker exec mail_dnsbl_enabled postconf smtpd_recipient_restrictions
  assert_output --partial 'reject_rbl_client zen.spamhaus.org'
}

@test "checking enabled postscreen DNS block lists --> postscreen_dnsbl_action" {
  run docker exec mail_dnsbl_enabled postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = enforce'
}

@test "checking enabled postscreen DNS block lists --> postscreen_dnsbl_sites" {
  run docker exec mail_dnsbl_enabled postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites = zen.spamhaus.org*3 bl.mailspike.net b.barracudacentral.org*2 bl.spameatingmonkey.net dnsbl.sorbs.net psbl.surriel.com list.dnswl.org=127.0.[0..255].0*-2 list.dnswl.org=127.0.[0..255].1*-3 list.dnswl.org=127.0.[0..255].[2..3]*-4'
}

# ENABLE_DNSBL=0
@test "checking disabled postfix DNS block list zen.spamhaus.org" {
  run docker exec mail_dnsbl_disabled postconf smtpd_recipient_restrictions
  refute_output --partial 'reject_rbl_client zen.spamhaus.org'
}

@test "checking disabled postscreen DNS block lists --> postscreen_dnsbl_action" {
  run docker exec mail_dnsbl_disabled postconf postscreen_dnsbl_action
  assert_output 'postscreen_dnsbl_action = ignore'
}

@test "checking disabled postscreen DNS block lists --> postscreen_dnsbl_sites" {
  run docker exec mail_dnsbl_disabled postconf postscreen_dnsbl_sites
  assert_output 'postscreen_dnsbl_sites ='
}

# cleanup
@test "checking that the container stops cleanly: mail_dnsbl_enabled" {
  run docker stop -t 0 mail_dnsbl_enabled
  assert_success
}

@test "checking that the container stops cleanly: mail_dnsbl_disabled" {
  run docker stop -t 0 mail_dnsbl_disabled
  assert_success
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}
