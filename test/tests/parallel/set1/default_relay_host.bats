load 'test_helper/common'

function setup() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container relay-hosts)

  docker run -d --name mail_with_default_relay \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e DEFAULT_RELAY_HOST=default.relay.host.invalid:25 \
    -e PERMIT_DOCKER=host \
    -h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_with_default_relay
}

function teardown() {
  docker rm -f mail_with_default_relay
}

#
# default relay host
#

@test "checking default relay host: default relay host is added to main.cf" {
  run docker exec mail_with_default_relay /bin/sh -c 'grep -e "^relayhost =" /etc/postfix/main.cf'
  assert_output 'relayhost = default.relay.host.invalid:25'
}
