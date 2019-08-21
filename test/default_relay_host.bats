load 'test_helper/common'

function setup() {
    docker run -d --name mail_with_default_relay \
		-v "`pwd`/test/config/relay-hosts":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e DEFAULT_RELAY_HOST=default.relay.host.invalid:25 \
		--cap-add=SYS_PTRACE \
		-e PERMIT_DOCKER=host \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t ${NAME}
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