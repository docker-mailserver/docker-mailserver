load 'test_helper/common'

setup() {
    run_setup_file_if_necessary
}

teardown() {
    run_teardown_file_if_necessary
}

setup_file() {
    docker run -d --name mail_special_use_folders \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
                -e SASL_PASSWD="external-domain.com username:password" \
                -e ENABLE_CLAMAV=0 \
                -e ENABLE_SPAMASSASSIN=0 \
                --cap-add=SYS_PTRACE \
                -e PERMIT_DOCKER=host \
                -e DMS_DEBUG=0 \
                -h mail.my-domain.com -t ${NAME}
    wait_for_smtp_port_in_container mail_special_use_folders
}

teardown_file() {
    docker rm -f mail_special_use_folders
}

@test "first" {
    skip 'only used to call setup_file from setup'
}


@test "checking normal delivery" {
  run docker exec mail_special_use_folders /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success

  repeat_until_success_or_timeout 30 docker exec mail_special_use_folders /bin/sh -c '[ $(ls /var/mail/localhost.localdomain/user1/new | wc -l) -eq 1 ]'
}

@test "checking special-use folders not yet created" {
  run docker exec mail_special_use_folders /bin/bash -c "ls -A /var/mail/localhost.localdomain/user1 | grep -E '.Drafts|.Sent|.Trash' | wc -l"
  assert_success
  assert_output 0
}

@test "checking special-use folders available in IMAP" {
  run docker exec mail_special_use_folders /bin/sh -c "nc -w 8 0.0.0.0 143 < /tmp/docker-mailserver-test/nc_templates/imap_special_use_folders.txt | grep -E 'Drafts|Junk|Trash|Sent' | wc -l"
  assert_success
  assert_output 4
}


@test "last" {
    skip 'only used to call teardown_file from teardown'
}
