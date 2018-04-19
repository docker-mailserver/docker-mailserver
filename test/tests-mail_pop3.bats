load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking pop: server is ready" {
  run docker exec mail_pop3 /bin/bash -c "nc -w 1 0.0.0.0 110 | grep '+OK'"
  assert_success
}

@test "checking pop: authentication works" {
  run docker exec mail_pop3 /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/pop3-auth.txt"
  assert_success
}

@test "checking pop: added user authentication works" {
  run docker exec mail_pop3 /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/added-pop3-auth.txt"
  assert_success
}

@test "checking spamassassin: docker env variables are set correctly (default)" {
  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  assert_success
  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  assert_success
  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  assert_success
  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= .\*\*\*SPAM\*\*\* .'"
  assert_success
}

@test "checking ssl: letsencrypt configuration is correct" {
  run docker exec mail_pop3 /bin/sh -c 'grep -ir "/etc/letsencrypt/live/mail.my-domain.com/" /etc/postfix/main.cf | wc -l'
  assert_success
  assert_output 2
  run docker exec mail_pop3 /bin/sh -c 'grep -ir "/etc/letsencrypt/live/mail.my-domain.com/" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
  assert_success
  assert_output 2
}

@test "checking ssl: letsencrypt cert works correctly" {
  run docker exec mail_pop3 /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

@test "checking system: /var/log/mail/mail.log is error free" {
  run docker exec mail_pop3 grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure
  run docker exec mail_pop3 grep ': error:' /var/log/mail/mail.log
  assert_failure
}

@test "checking manage sieve: disabled per default" {
  run docker exec mail_pop3 /bin/bash -c "nc -z 0.0.0.0 4190"
  assert_failure
}

@test "checking PERMIT_DOCKER: my network value" {
  run docker exec mail_pop3 /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}/32'"
  assert_success
}

