load 'test_helper/common'

# Test case
# ---------
# POSTFIX_INET_PROTOCOLS value is set


function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    docker run -d --name mail_postfix_inet_default \
		-v "$(duplicate_config_for_container . mail_postfix_inet_default)":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_postfix_inet_default

    docker run -d --name mail_postfix_inet_all \
		-v "$(duplicate_config_for_container . mail_postfix_inet_all)":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-e POSTFIX_INET_PROTOCOLS=all \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_postfix_inet_all

    docker run -d --name mail_postfix_inet_ipv4 \
		-v "$(duplicate_config_for_container . mail_postfix_inet_ipv4)":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-e POSTFIX_INET_PROTOCOLS=ipv4 \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_postfix_inet_ipv4

    docker run -d --name mail_postfix_inet_ipv6 \
		-v "$(duplicate_config_for_container . mail_postfix_inet_ipv6)":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-e POSTFIX_INET_PROTOCOLS=ipv6 \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_postfix_inet_ipv6
}

function teardown_file() {
    docker rm -f mail_postfix_inet_default
    docker rm -f mail_postfix_inet_all
    docker rm -f mail_postfix_inet_ipv4
    docker rm -f mail_postfix_inet_ipv6
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking postfix: inet default" {
  run docker exec mail_postfix_inet_default postconf inet_protocols
  assert_output "inet_protocols = all"
  assert_success
}
@test "checking postfix: inet all" {
  run docker exec mail_postfix_inet_all postconf inet_protocols
  assert_output "inet_protocols = all"
  assert_success
}
@test "checking postfix: inet ipv4" {
  run docker exec mail_postfix_inet_ipv4 postconf inet_protocols
  assert_output "inet_protocols = ipv4"
  assert_success
}
@test "checking postfix: inet ipv6" {
  run docker exec mail_postfix_inet_ipv6 postconf inet_protocols
  assert_output "inet_protocols = ipv6"
  assert_success
}

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
