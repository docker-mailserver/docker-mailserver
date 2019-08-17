load 'test_helper/common'

setup() {
    run_setup_file_if_necessary
}

teardown() {
    run_teardown_file_if_necessary
}

setup_file() {
    docker run -d --name mail_lmtp_ip \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/config/dovecot-lmtp":/etc/dovecot \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e ENABLE_POSTFIX_VIRTUAL_TRANSPORT=1 \
		-e POSTFIX_DAGENT=lmtp:127.0.0.1:24 \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t ${NAME}
    wait_for_finished_setup_in_container mail_lmtp_ip
}


teardown_file() {
    docker rm -f mail_lmtp_ip
}

@test "first" {
    skip 'only used to call setup_file from setup'
}

#
# Postfix VIRTUAL_TRANSPORT
#
@test "checking postfix-lmtp: virtual_transport config is set" {
  run docker exec mail_lmtp_ip /bin/sh -c "grep 'virtual_transport = lmtp:127.0.0.1:24' /etc/postfix/main.cf"
  assert_success
}

@test "checking postfix-lmtp: delivers mail to existing account" {
  # maybe we can move this into the setup to speed things up futher.
  # this likely would need an async coroutine to avoid blocking the other tests while waiting for the server to come up
  wait_for_smtp_port_in_container mail_lmtp_ip
  run docker exec mail_lmtp_ip /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success
  
  # polling needs to avoid wc -l's unconditionally successful return status
  repeat_until_success_or_timeout 60 docker exec mail_lmtp_ip /bin/sh -c "grep 'postfix/lmtp' /var/log/mail/mail.log | grep 'status=sent' | grep ' Saved)'"
  run docker exec mail_lmtp_ip /bin/sh -c "grep 'postfix/lmtp' /var/log/mail/mail.log | grep 'status=sent' | grep ' Saved)' | wc -l"
  assert_success
  assert_output 1
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}