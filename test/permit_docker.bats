load 'test_helper/common'

NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME=non-default-docker-mail-network
setup() {
    docker network create --driver bridge ${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}
	docker network create --driver bridge ${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}2
	# use two networks (default ("bridge") and our custom network) to recreate problematic test case where PERMIT_DOCKER=host would not help
	# currently we cannot use --network in `docker run` multiple times, it will just use the last one
	# instead we need to use create, network connect and start (see https://success.docker.com/article/multiple-docker-networks)
	docker create --name mail_smtponly_second_network \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e SMTP_ONLY=1 \
		-e PERMIT_DOCKER=connected-networks \
		-e DMS_DEBUG=0 \
		-e OVERRIDE_HOSTNAME=mail.my-domain.com \
		--network ${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME} \
		-t ${NAME}
	docker network connect ${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}2 mail_smtponly_second_network
	docker start mail_smtponly_second_network
	docker run -d --name mail_smtponly_second_network_sender \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e SMTP_ONLY=1 \
		-e PERMIT_DOCKER=connected-networks \
		-e DMS_DEBUG=0 \
		-e OVERRIDE_HOSTNAME=mail.my-domain.com \
		--network ${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}2 \
		-t ${NAME}

    # wait until postfix is up
    wait_for_smtp_port_in_container mail_smtponly_second_network
}

teardown() {
    docker logs mail_smtponly_second_network
    docker rm -f mail_smtponly_second_network \
		        mail_smtponly_second_network_sender
    docker network rm ${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME} ${NON_DEFAULT_DOCKER_MAIL_NETWORK_NAME}2
}

@test "checking PERMIT_DOCKER: connected-networks" {
  ipnet1=$(docker network inspect --format '{{(index .IPAM.Config 0).Subnet}}' non-default-docker-mail-network)
  ipnet2=$(docker network inspect --format '{{(index .IPAM.Config 0).Subnet}}' non-default-docker-mail-network2)
  run docker exec mail_smtponly_second_network /bin/sh -c "postconf | grep '^mynetworks ='"
  assert_output --partial $ipnet1
  assert_output --partial $ipnet2

  run docker exec mail_smtponly_second_network /bin/sh -c "postconf -e smtp_host_lookup=no"
  assert_success
  run docker exec mail_smtponly_second_network /bin/sh -c "/etc/init.d/postfix reload"
  assert_success
  # we should be able to send from the other container on the second network!
  run docker exec mail_smtponly_second_network_sender /bin/sh -c "nc mail_smtponly_second_network 25 < /tmp/docker-mailserver-test/email-templates/smtp-only.txt"
  assert_output --partial "250 2.0.0 Ok: queued as "

  repeat_until_success_or_timeout 60 run docker exec mail_smtponly_second_network /bin/sh -c 'grep -cE "to=<user2\@external.tld>.*status\=sent" /var/log/mail/mail.log'
  [ "$status" -ge 0 ]
}