load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    docker run -d --name mail_privacy \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e SASL_PASSWD="external-domain.com username:password" \
		-e ENABLE_MANAGESIEVE=1 \
		--cap-add=SYS_PTRACE \
		-e PERMIT_DOCKER=host \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t ${NAME}

    wait_for_amavis_port_in_container mail_privacy
    wait_for_smtp_port_in_container mail_privacy
}

function teardown_file() {
    docker rm -f mail_privacy
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

#
# LDAP
#

# postfix

@test "checking postfix: remove privacy details of the sender" {
  docker exec mail_privacy /bin/sh -c "openssl s_client -quiet -starttls smtp -connect 0.0.0.0:587 < /tmp/docker-mailserver-test/email-templates/send-privacy-email.txt"
  repeat_until_success_or_timeout 120 docker exec mail_privacy /bin/sh -c '[ $(ls /var/mail/localhost.localdomain/user1/new | wc -l) -eq 1 ]'
  docker logs mail_privacy
  run docker exec mail_privacy /bin/sh -c "ls /var/mail/localhost.localdomain/user1/new | wc -l"
  assert_success
  assert_output 1
  run docker exec mail_privacy /bin/sh -c "grep -rE "^User-Agent:" /var/mail/localhost.localdomain/user1/new | wc -l"
  assert_success
  assert_output 0
}


@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
