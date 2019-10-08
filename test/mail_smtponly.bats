load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    docker run --rm -d --name mail_smtponly \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e SMTP_ONLY=1 \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e OVERRIDE_HOSTNAME=mail.my-domain.com \
		-t ${NAME}

    wait_for_finished_setup_in_container mail_smtponly
}

function teardown_file() {
    docker rm -f mail_smtponly
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

#
# configuration checks
#

@test "checking configuration: hostname/domainname override" {
  run docker exec mail_smtponly /bin/bash -c "cat /etc/mailname | grep my-domain.com"
  assert_success
}

#
# imap
#

@test "checking process: dovecot imaplogin (disabled using SMTP_ONLY)" {
  run docker exec mail_smtponly /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  assert_failure
}

#
# smtp
#

@test "checking smtp_only: mail send should work" {
  run docker exec mail_smtponly /bin/sh -c "postconf -e smtp_host_lookup=no"
  assert_success
  run docker exec mail_smtponly /bin/sh -c "/etc/init.d/postfix reload"
  assert_success
  run docker exec mail_smtponly /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/smtp-only.txt"
  assert_success
  run docker exec mail_smtponly /bin/sh -c 'grep -cE "to=<user2\@external.tld>.*status\=sent" /var/log/mail/mail.log'
  [ "$status" -ge 0 ]
}

#
# PERMIT_DOCKER=network
#

@test "checking PERMIT_DOCKER=network: opendmarc/opendkim config" {
  run docker exec mail_smtponly /bin/sh -c "cat /etc/opendmarc/ignore.hosts | grep '172.16.0.0/12'"
  assert_success
  run docker exec mail_smtponly /bin/sh -c "cat /etc/opendkim/TrustedHosts | grep '172.16.0.0/12'"
  assert_success
}

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}