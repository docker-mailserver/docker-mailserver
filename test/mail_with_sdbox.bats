load 'test_helper/common'

setup() {
    run_setup_file_if_necessary
}

teardown() {
    run_teardown_file_if_necessary
}

setup_file() {
    docker run -d --name mail_with_sdbox_format \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
                -e SASL_PASSWD="external-domain.com username:password" \
                -e ENABLE_CLAMAV=0 \
                -e ENABLE_SPAMASSASSIN=0 \
                -e DOVECOT_MAILBOX_FORMAT=sdbox \
                --cap-add=SYS_PTRACE \
                -e PERMIT_DOCKER=host \
                -e DMS_DEBUG=0 \
                -h mail.my-domain.com -t ${NAME}
    wait_for_smtp_port_in_container mail_with_sdbox_format
}

teardown_file() {
    docker rm -f mail_with_sdbox_format
}

@test "first" {
    skip 'only used to call setup_file from setup'
}


@test "checking dovecot mailbox format: sdbox file created" {
  run docker exec mail_with_sdbox_format /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success

  repeat_until_success_or_timeout 30 docker exec mail_with_sdbox_format /bin/sh -c '[ $(ls /var/mail/localhost.localdomain/user1/mailboxes/INBOX/dbox-Mails/u.1 | wc -l) -eq 1 ]'
}


@test "last" {
    skip 'only used to call teardown_file from teardown'
}
