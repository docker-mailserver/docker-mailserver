load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking process: saslauthd (saslauthd server enabled)" {
  run docker exec mail_with_ldap /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
  assert_success
}

@test "checking postfix: ldap lookup works correctly" {
  run docker exec mail_with_ldap /bin/sh -c "postmap -q some.user@localhost.localdomain ldap:/etc/postfix/ldap-users.cf"
  assert_success
  assert_output "some.user@localhost.localdomain"
  run docker exec mail_with_ldap /bin/sh -c "postmap -q postmaster@localhost.localdomain ldap:/etc/postfix/ldap-aliases.cf"
  assert_success
  assert_output "some.user@localhost.localdomain"
  run docker exec mail_with_ldap /bin/sh -c "postmap -q employees@localhost.localdomain ldap:/etc/postfix/ldap-groups.cf"
  assert_success
  assert_output "some.user@localhost.localdomain"

  # Test of the user part of the domain is not the same as the uniqueIdentifier part in the ldap
  run docker exec mail_with_ldap /bin/sh -c "postmap -q some.user.email@localhost.localdomain ldap:/etc/postfix/ldap-users.cf"
  assert_success
  assert_output "some.user.email@localhost.localdomain"

  # Test email receiving from a other domain then the primary domain of the mailserver
  run docker exec mail_with_ldap /bin/sh -c "postmap -q some.other.user@localhost.otherdomain ldap:/etc/postfix/ldap-users.cf"
  assert_success
  assert_output "some.other.user@localhost.otherdomain"
  run docker exec mail_with_ldap /bin/sh -c "postmap -q postmaster@localhost.otherdomain ldap:/etc/postfix/ldap-aliases.cf"
  assert_success
  assert_output "some.other.user@localhost.otherdomain"
  run docker exec mail_with_ldap /bin/sh -c "postmap -q employees@localhost.otherdomain ldap:/etc/postfix/ldap-groups.cf"
  assert_success
  assert_output "some.other.user@localhost.otherdomain"
}

@test "checking postfix: ldap custom config files copied" {
 run docker exec mail_with_ldap /bin/sh -c "grep '# Testconfig for ldap integration' /etc/postfix/ldap-users.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep '# Testconfig for ldap integration' /etc/postfix/ldap-groups.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep '# Testconfig for ldap integration' /etc/postfix/ldap-aliases.cf"
 assert_success
}

@test "checking postfix: ldap config overwrites success" {
 run docker exec mail_with_ldap /bin/sh -c "grep 'server_host = ldap' /etc/postfix/ldap-users.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'start_tls = no' /etc/postfix/ldap-users.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-users.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-users.cf"
 assert_success

 run docker exec mail_with_ldap /bin/sh -c "grep 'server_host = ldap' /etc/postfix/ldap-groups.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'start_tls = no' /etc/postfix/ldap-groups.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-groups.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-groups.cf"
 assert_success

 run docker exec mail_with_ldap /bin/sh -c "grep 'server_host = ldap' /etc/postfix/ldap-aliases.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'start_tls = no' /etc/postfix/ldap-aliases.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-aliases.cf"
 assert_success
 run docker exec mail_with_ldap /bin/sh -c "grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-aliases.cf"
 assert_success
}

@test "checking dovecot: ldap imap connection and authentication works" {
  run docker exec mail_with_ldap /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-ldap-auth.txt"
  assert_success
}

@test "checking dovecot: ldap mail delivery works" {
  run docker exec mail_with_ldap /bin/sh -c "sendmail -f user@external.tld some.user@localhost.localdomain < /tmp/docker-mailserver-test/email-templates/test-email.txt"
  sleep 10
  run docker exec mail_with_ldap /bin/sh -c "ls -A /var/mail/localhost.localdomain/some.user/new | wc -l"
  assert_success
  assert_output 1
}

@test "checking dovecot: ldap mail delivery works for a different domain then the mailserver" {
  run docker exec mail_with_ldap /bin/sh -c "sendmail -f user@external.tld some.other.user@localhost.otherdomain < /tmp/docker-mailserver-test/email-templates/test-email.txt"
  sleep 10
  run docker exec mail_with_ldap /bin/sh -c "ls -A /var/mail/localhost.localdomain/some.other.user/new | wc -l"
  assert_success
  assert_output 1
}

@test "checking dovecot: ldap config overwrites success" {
  run docker exec mail_with_ldap /bin/sh -c "grep 'hosts = ldap' /etc/dovecot/dovecot-ldap.conf.ext"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "grep 'tls = no' /etc/dovecot/dovecot-ldap.conf.ext"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "grep 'base = ou=people,dc=localhost,dc=localdomain' /etc/dovecot/dovecot-ldap.conf.ext"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "grep 'dn = cn=admin,dc=localhost,dc=localdomain' /etc/dovecot/dovecot-ldap.conf.ext"
  assert_success
}

@test "checking dovecot: postmaster address" {
  run docker exec mail_with_ldap /bin/sh -c "grep 'postmaster_address = postmaster@localhost.localdomain' /etc/dovecot/conf.d/15-lda.conf"
  assert_success
}

@test "checking spoofing: rejects sender forging" {
  # checking rejection of spoofed sender
  # checking ldap
  run docker exec mail_with_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed.txt | grep 'Sender address rejected: not owned by user'"
  assert_success
}

@test "checking spoofing: accepts sending as alias" {
  # checking ldap alias
  run docker exec mail_with_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed-alias.txt | grep 'End data with'"
  assert_success
}

@test "checking saslauthd: sasl ldap authentication works" {
  run docker exec mail_with_ldap bash -c "testsaslauthd -u some.user -p secret"
  assert_success
}

@test "checking saslauthd: ldap smtp authentication" {
  run docker exec mail_with_ldap /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt | grep 'Authentication successful'"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt | grep 'Authentication successful'"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "openssl s_client -quiet -starttls smtp -connect 0.0.0.0:587 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking pflogsum delivery" {
  # checking default logrotation setup
  run docker exec mail_with_ldap grep "daily" /etc/logrotate.d/maillog
  assert_success
}

@test "checking restart of process: saslauthd (saslauthd server enabled)" {
  run docker exec mail_with_ldap /bin/bash -c "pkill saslauthd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
  assert_success
}

