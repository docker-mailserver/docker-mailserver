load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking dovecot: ldap rimap connection and authentication works" {
  run docker exec mail_with_imap /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-auth.txt"
  assert_success
}

@test "checking saslauthd: sasl rimap authentication works" {
  run docker exec mail_with_imap bash -c "testsaslauthd -u user1@localhost.localdomain -p mypassword"
  assert_success
}

@test "checking saslauthd: rimap smtp authentication" {
  run docker exec mail_with_imap /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt | grep 'Authentication successful'"
  assert_success
}

