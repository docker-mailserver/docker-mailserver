load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    # We use a temporary config directory since we'll be dynamically editing
    # it with setup.sh.
    tmp_confdir=$(mktemp -d /tmp/docker-mailserver-config-relay-hosts-XXXXX)
    cp -aT test/config/relay-hosts "$tmp_confdir"

    docker run -d --name mail_with_relays \
            -v "$tmp_confdir":/tmp/docker-mailserver \
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
    rm -rf "$tmp_confdir"
}

@test "first" {
  # this test must come first to reliably identify when to run setup_file
}

@test "checking relay hosts: default mapping is added from env vars" {
  run docker exec mail_with_relays grep -e domainone.tld /etc/postfix/relayhost_map
  assert_output -e '^@domainone.tld\s+\[default.relay.com\]:2525$'
}

@test "checking relay hosts: default mapping is added from env vars for virtual user entry" {
  run docker exec mail_with_relays grep -e domain1.tld /etc/postfix/relayhost_map
  assert_output -e '^@domain1.tld\s+\[default.relay.com\]:2525$'
}

@test "checking relay hosts: default mapping is added from env vars for new user entry" {
  run docker exec mail_with_relays grep -e domainzero.tld /etc/postfix/relayhost_map
  assert_output ''
  run ./setup.sh -c mail_with_relays email add user0@domainzero.tld password123
  run_until_success_or_timeout 10 docker exec mail_with_relays grep -e domainzero.tld /etc/postfix/relayhost_map
  assert_output -e '^@domainzero.tld\s+\[default.relay.com\]:2525$'
}

@test "checking relay hosts: default mapping is added from env vars for new virtual user entry" {
  run docker exec mail_with_relays grep -e domain2.tld /etc/postfix/relayhost_map
  assert_output ''
  run ./setup.sh -c mail_with_relays alias add user2@domain2.tld user2@domaintwo.tld
  run_until_success_or_timeout 10 docker exec mail_with_relays grep -e domain2.tld /etc/postfix/relayhost_map
  assert_output -e '^@domain2.tld\s+\[default.relay.com\]:2525$'
}

@test "checking relay hosts: custom mapping is added from file" {
  run docker exec mail_with_relays grep -e domaintwo.tld /etc/postfix/relayhost_map
  assert_output -e '^@domaintwo.tld\s+\[other.relay.com\]:587$'
}

@test "checking relay hosts: ignored domain is not added" {
  run docker exec mail_with_relays grep -e domainthree.tld /etc/postfix/relayhost_map
  assert_failure 1
  assert_output ''
}

@test "checking relay hosts: auth entry is added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/sasl_passwd | grep -e "^@domaintwo.tld\s\+smtp_user_2:smtp_password_2" | wc -l'
  assert_success
  assert_output 1
}

@test "checking relay hosts: default auth entry is added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/sasl_passwd | grep -e "^\[default.relay.com\]:2525\s\+smtp_user:smtp_password" | wc -l'
  assert_success
  assert_output 1
}

@test "last" {
  # this test is only there to reliably mark the end for the teardown_file
}
