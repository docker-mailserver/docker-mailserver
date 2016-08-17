#
# imap
#

@test "checking process: dovecot imaplogin (enabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  [ "$status" -eq 0 ]
}

@test "checking imap: server is ready with STARTTLS" {
  run docker exec mail /bin/bash -c "nc -w 2 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'ready'"
  [ "$status" -eq 0 ]
}

@test "checking imap: authentication works" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-auth.txt"
  [ "$status" -eq 0 ]
}

#
# logs
#

@test "checking logs: mail related logs should be located in a subdirectory" {
  run docker exec mail /bin/sh -c "ls -1 /var/log/mail/ | grep -E 'clamav|freshclam|mail'|wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 3 ]
}

#
# smtp
#

@test "checking smtp: authentication works with good password (plain)" {
  run docker exec mail /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-plain.txt | grep 'Authentication successful'"
  [ "$status" -eq 0 ]
}

@test "checking smtp: authentication fails with wrong password (plain)" {
  run docker exec mail /bin/sh -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-plain-wrong.txt | grep 'authentication failed'"
  [ "$status" -eq 0 ]
}

@test "checking smtp: authentication works with good password (login)" {
  run docker exec mail /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt | grep 'Authentication successful'"
  [ "$status" -eq 0 ]
}

@test "checking smtp: authentication fails with wrong password (login)" {
  run docker exec mail /bin/sh -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt | grep 'authentication failed'"
  [ "$status" -eq 0 ]
}

@test "checking smtp: delivers mail to existing account" {
  run docker exec mail /bin/sh -c "grep 'status=sent (delivered via dovecot service)' /var/log/mail/mail.log | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 6 ]
}

@test "checking smtp: delivers mail to existing alias" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<alias1@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

@test "checking smtp: delivers mail to existing catchall" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<wildcard@localdomain2.com>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

@test "checking smtp: delivers mail to regexp alias" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<test123@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

@test "checking smtp: user1 should have received 5 mails" {
  run docker exec mail /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 5 ]
}

@test "checking smtp: rejects mail to unknown user" {
  run docker exec mail /bin/sh -c "grep '<nouser@localhost.localdomain>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail/mail.log | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

@test "checking smtp: redirects mail to external aliases" {
  run docker exec mail /bin/sh -c "grep -- '-> <external1@otherdomain.tld>' /var/log/mail/mail.log | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 2 ]
}

@test "checking smtp: rejects spam" {
  run docker exec mail /bin/sh -c "grep 'Blocked SPAM' /var/log/mail/mail.log | grep spam@external.tld | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

@test "checking smtp: rejects virus" {
  run docker exec mail /bin/sh -c "grep 'Blocked INFECTED' /var/log/mail/mail.log | grep virus@external.tld | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

#
# accounts
#

@test "checking accounts: user accounts" {
  run docker exec mail doveadm user '*'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "user1@localhost.localdomain" ]
  [ "${lines[1]}" = "user2@otherdomain.tld" ]
}

@test "checking accounts: user mail folders for user1" {
  run docker exec mail /bin/bash -c "ls -A /var/mail/localhost.localdomain/user1 | grep -E '.Drafts|.Sent|.Trash|cur|new|subscriptions|tmp' | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 7 ]
}

@test "checking accounts: user mail folders for user2" {
  run docker exec mail /bin/bash -c "ls -A /var/mail/otherdomain.tld/user2 | grep -E '.Drafts|.Sent|.Trash|cur|new|subscriptions|tmp' | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 7 ]
}

#
# postfix
#

@test "checking postfix: vhost file is correct" {
  run docker exec mail cat /etc/postfix/vhost
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "localdomain2.com" ]
  [ "${lines[1]}" = "localhost.localdomain" ]
  [ "${lines[2]}" = "otherdomain.tld" ]
}

@test "checking postfix: main.cf overrides" {
  run docker exec mail grep -q 'max_idle = 600s' /tmp/docker-mailserver/postfix-main.cf
  [ "$status" -eq 0 ]
  run docker exec mail grep -q 'readme_directory = /tmp' /tmp/docker-mailserver/postfix-main.cf
  [ "$status" -eq 0 ]
}

#
# dovecot
#

@test "checking dovecot: config additions" {
  run docker exec mail grep -q 'mail_max_userip_connections = 69' /tmp/docker-mailserver/dovecot.cf
  [ "$status" -eq 0 ]
  run docker exec mail /bin/sh -c "doveconf | grep 'mail_max_userip_connections = 69'"
  [ "$status" -eq 0 ]
  [ "$output" = 'mail_max_userip_connections = 69' ]
}