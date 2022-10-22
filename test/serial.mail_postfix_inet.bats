load 'test_helper/common'

# Test case
# ---------
# POSTFIX_INET_PROTOCOLS value is set

@test "checking postfix: inet default" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . )

  docker run -d --name mail_postfix_inet_default \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_postfix_inet_default; }

  wait_for_finished_setup_in_container mail_postfix_inet_default

  run docker exec mail_postfix_inet_default postconf inet_protocols
  assert_output "inet_protocols = all"
  assert_success
}

@test "checking postfix: inet all" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . )

  docker run -d --name mail_postfix_inet_all \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e POSTFIX_INET_PROTOCOLS=all \
    -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_postfix_inet_all; }

  wait_for_finished_setup_in_container mail_postfix_inet_all

  run docker exec mail_postfix_inet_all postconf inet_protocols
  assert_output "inet_protocols = all"
  assert_success
}

@test "checking postfix: inet ipv4" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . )

  docker run -d --name mail_postfix_inet_ipv4 \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e POSTFIX_INET_PROTOCOLS=ipv4 \
    -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_postfix_inet_ipv4; }

  wait_for_finished_setup_in_container mail_postfix_inet_ipv4

  run docker exec mail_postfix_inet_ipv4 postconf inet_protocols
  assert_output "inet_protocols = ipv4"
  assert_success
}

@test "checking postfix: inet ipv6" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . )

  docker run -d --name mail_postfix_inet_ipv6 \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e POSTFIX_INET_PROTOCOLS=ipv6 \
    -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_postfix_inet_ipv6; }

  wait_for_finished_setup_in_container mail_postfix_inet_ipv6

  run docker exec mail_postfix_inet_ipv6 postconf inet_protocols
  assert_output "inet_protocols = ipv6"
  assert_success
}
