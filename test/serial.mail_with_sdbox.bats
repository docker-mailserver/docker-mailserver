load 'test_helper/common'

setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_with_sdbox_format \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e SASL_PASSWD="external-domain.com username:password" \
    -e ENABLE_CLAMAV=0 \
    -e ENABLE_SPAMASSASSIN=0 \
    -e DOVECOT_MAILBOX_FORMAT=sdbox \
    -e PERMIT_DOCKER=host \
    -h mail.my-domain.com -t "${NAME}"

  wait_for_smtp_port_in_container mail_with_sdbox_format
}

teardown_file() {
  docker rm -f mail_with_sdbox_format
}

@test "checking dovecot mailbox format: sdbox file created" {
  run docker exec mail_with_sdbox_format /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success

  # shellcheck disable=SC2016
  repeat_until_success_or_timeout 30 docker exec mail_with_sdbox_format /bin/sh -c '[ $(ls /var/mail/localhost.localdomain/user1/mailboxes/INBOX/dbox-Mails/u.1 | wc -l) -eq 1 ]'
}
