load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    docker run -d --name mail_with_relays \
            -v "`pwd`/test/config/relay-hosts":/tmp/docker-mailserver \
            -v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
            -e RELAY_HOST=default.relay.com \
            -e RELAY_PORT=2525 \
            -e RELAY_USER=smtp_user \
            -e RELAY_PASSWORD=smtp_password \
            --cap-add=SYS_PTRACE \
            -e PERMIT_DOCKER=host \
            -e DMS_DEBUG=0 \
            -h mail.my-domain.com -t ${NAME}
        wait_for_finished_setup_in_container mail_with_relays
}

function teardown_file() {
    docker rm -f mail_with_relays
}

@test "first" {
  # this test must come first to reliably identify when to run setup_file
}

@test "checking relay hosts: default mapping is added from env vars" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domainone.tld\s\+\[default.relay.com\]:2525" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: custom mapping is added from file" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domaintwo.tld\s\+\[other.relay.com\]:587" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: ignored domain is not added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domainthree.tld\s\+\[any.relay.com\]:25" | wc -l | grep 0'
  assert_success
}

@test "checking relay hosts: auth entry is added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/sasl_passwd | grep -e "^@domaintwo.tld\s\+smtp_user_2:smtp_password_2" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: default auth entry is added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/sasl_passwd | grep -e "^\[default.relay.com\]:2525\s\+smtp_user:smtp_password" | wc -l | grep 1'
  assert_success
}

@test "last" {
  # this test is only there to reliably mark the end for the teardown_file
}