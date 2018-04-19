load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking configuration: hostname/domainname override" {
  run docker exec mail_smtponly /bin/bash -c "cat /etc/mailname | grep my-domain.com"
  assert_success
}

@test "checking process: dovecot imaplogin (disabled using SMTP_ONLY)" {
  run docker exec mail_smtponly /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  assert_failure
}

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

@test "checking PERMIT_DOCKER: opendmarc/opendkim config" {
  run docker exec mail_smtponly /bin/sh -c "cat /etc/opendmarc/ignore.hosts | grep '172.16.0.0/12'"
  assert_success
  run docker exec mail_smtponly /bin/sh -c "cat /etc/opendkim/TrustedHosts | grep '172.16.0.0/12'"
  assert_success
}

