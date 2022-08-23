load 'test_helper/common'

NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME=non-default-docker-mail-network
setup_file() {
  docker network create --driver bridge "${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}"
  docker network create --driver bridge "${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}2"

  # use two networks (default ("bridge") and our custom network) to recreate problematic test case where PERMIT_DOCKER=host would not help
  # currently we cannot use --network in `docker run` multiple times, it will just use the last one
  # instead we need to use create, network connect and start (see https://success.docker.com/article/multiple-docker-networks)
  local PRIVATE_CONFIG

  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_smtponly_second_network)
  docker create --name mail_smtponly_second_network \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e SMTP_ONLY=1 \
    -e PERMIT_DOCKER=connected-networks \
    -e OVERRIDE_HOSTNAME=mail.my-domain.com \
    --network "${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}" \
    -t "${NAME}"

  docker network connect "${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}2" mail_smtponly_second_network
  docker start mail_smtponly_second_network

  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_smtponly_second_network_sender)
  docker run -d --name mail_smtponly_second_network_sender \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e SMTP_ONLY=1 \
    -e PERMIT_DOCKER=connected-networks \
    -e OVERRIDE_HOSTNAME=mail.my-domain.com \
    --network "${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}2" \
    -t "${NAME}"

  # wait until postfix is up
  wait_for_smtp_port_in_container mail_smtponly_second_network

  # create another container that enforces authentication even on local connections
  docker run -d --name mail_smtponly_force_authentication \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e SMTP_ONLY=1 \
    -e PERMIT_DOCKER=none \
    -e OVERRIDE_HOSTNAME=mail.my-domain.com \
    -t "${NAME}"

  # wait until postfix is up
  wait_for_smtp_port_in_container mail_smtponly_force_authentication
}

teardown_file() {
  docker logs mail_smtponly_second_network
  docker rm -f mail_smtponly_second_network mail_smtponly_second_network_sender mail_smtponly_force_authentication
  docker network rm "${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}" "${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}2"
}

@test "checking PERMIT_DOCKER: connected-networks" {
  IPNET1=$(docker network inspect --format '{{(index .IPAM.Config 0).Subnet}}' non-default-docker-mail-network)
  IPNET2=$(docker network inspect --format '{{(index .IPAM.Config 0).Subnet}}' non-default-docker-mail-network2)
  run docker exec mail_smtponly_second_network /bin/sh -c "postconf | grep '^mynetworks ='"
  assert_output --partial "${IPNET1}"
  assert_output --partial "${IPNET2}"

  run docker exec mail_smtponly_second_network /bin/sh -c "postconf -e smtp_host_lookup=no"
  assert_success

  run docker exec mail_smtponly_second_network /bin/sh -c "/etc/init.d/postfix reload"
  assert_success

  # we should be able to send from the other container on the second network!
  run docker exec mail_smtponly_second_network_sender /bin/sh -c "nc mail_smtponly_second_network 25 < /tmp/docker-mailserver-test/email-templates/smtp-only.txt"
  assert_output --partial "250 2.0.0 Ok: queued as "
  repeat_until_success_or_timeout 60 run docker exec mail_smtponly_second_network /bin/sh -c 'grep -cE "to=<user2\@external.tld>.*status\=sent" /var/log/mail/mail.log'
  [[ ${status} -ge 0 ]]
}

@test "checking PERMIT_DOCKER: none" {
  run docker exec mail_smtponly_force_authentication /bin/sh -c "postconf -e smtp_host_lookup=no"
  assert_success

  run docker exec mail_smtponly_force_authentication /bin/sh -c "/etc/init.d/postfix reload"
  assert_success

  # the mailserver should require authentication and a protocol error should occur when using TLS
  run docker exec mail_smtponly_force_authentication /bin/sh -c "nc localhost 25 < /tmp/docker-mailserver-test/email-templates/smtp-only.txt"
  assert_output --partial "550 5.5.1 Protocol error"
  [[ ${status} -ge 0 ]]
}
