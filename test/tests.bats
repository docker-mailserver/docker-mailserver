#
# processes
#

@test "checking process: postfix" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/postfix/master'"
  [ "$status" -eq 0 ]
}

@test "checking process: saslauthd" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
  [ "$status" -eq 0 ]
}

@test "checking process: clamd" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  [ "$status" -eq 0 ]
}

@test "checking process: new" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/amavisd-new'"
  [ "$status" -eq 0 ]
}

@test "checking process: opendkim" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/opendkim'"
  [ "$status" -eq 0 ]
}

@test "checking process: opendmarc" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/opendmarc'"
  [ "$status" -eq 0 ]
}

@test "checking process: fail2ban (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/python /usr/bin/fail2ban-server'"
  [ "$status" -eq 1 ]
}

@test "checking process: fail2ban (fail2ban server enabled)" {
  run docker exec mail_fail2ban /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/python /usr/bin/fail2ban-server'"
  [ "$status" -eq 0 ]
}

@test "checking process: courierpop3d (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/courier/courier/courierpop3d'"
  [ "$status" -eq 1 ]
}

@test "checking process: courierpop3d (pop3 server enabled)" {
  run docker exec mail_pop3 /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/courier/courier/courierpop3d'"
  [ "$status" -eq 0 ]
}

@test "checking process: courierpop3d (disabled using SMTP_ONLY)" {
  run docker exec mail_smtponly /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/courier/courier/courierpop3d'"
  [ "$status" -eq 1 ]
}


#
# imap
#

@test "checking process: courier imaplogin (enabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/courier/courier/imaplogin'"
  [ "$status" -eq 0 ]
}

@test "checking process: courier imaplogin (disabled using SMTP_ONLY)" {
  run docker exec mail_smtponly /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/courier/courier/imaplogin'"
  [ "$status" -eq 1 ]
}

@test "checking imap: server is ready with STARTTLS" {
  run docker exec mail /bin/bash -c "nc -w 1 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'Courier-IMAP ready'"
  [ "$status" -eq 0 ]
}

@test "checking imap: authentication works" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/test/auth/imap-auth.txt"
  [ "$status" -eq 0 ]
}

#
# pop
#

@test "checking pop: server is ready" {
  run docker exec mail_pop3 /bin/bash -c "nc -w 1 0.0.0.0 110 | grep '+OK'"
  [ "$status" -eq 0 ]
}

@test "checking pop: authentication works" {
  run docker exec mail_pop3 /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/test/auth/pop3-auth.txt"
  [ "$status" -eq 0 ]
}

#
# sasl
#

@test "checking sasl: testsaslauthd works with good password" {
  run docker exec mail /bin/sh -c "testsaslauthd -u user2 -r otherdomain.tld -p mypassword | grep 'OK \"Success.\"'"
  [ "$status" -eq 0 ]
}

@test "checking sasl: testsaslauthd fails with bad password" {
  run docker exec mail /bin/sh -c "testsaslauthd -u user2 -r otherdomain.tld -p BADPASSWORD | grep 'NO \"authentication failed\"'"
  [ "$status" -eq 0 ]
}

@test "checking sasl: sasl_passwd.db exists" {
  run docker exec mail [ -f /etc/postfix/sasl_passwd.db ]
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
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-plain.txt | grep 'Authentication successful'"
  [ "$status" -eq 0 ]
}

@test "checking smtp: authentication fails with wrong password (plain)" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-plain-wrong.txt | grep 'authentication failed'"
  [ "$status" -eq 0 ]
}

@test "checking smtp: authentication works with good password (login)" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-login.txt | grep 'Authentication successful'"
  [ "$status" -eq 0 ]
}

@test "checking smtp: authentication fails with wrong password (login)" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-login-wrong.txt | grep 'authentication failed'"
  [ "$status" -eq 0 ]
}

@test "checking smtp: delivers mail to existing account" {
  run docker exec mail /bin/sh -c "grep 'status=sent (delivered to maildir)' /var/log/mail/mail.log | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

@test "checking smtp: delivers mail to existing alias" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<alias1@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

@test "checking smtp: user1 should have received 2 mails" {
  run docker exec mail /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 2 ]
}

@test "checking smtp: rejects mail to unknown user" {
  run docker exec mail /bin/sh -c "grep '<nouser@localhost.localdomain>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail/mail.log | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

@test "checking smtp: redirects mail to external alias" {
  run docker exec mail /bin/sh -c "grep -- '-> <external1@otherdomain.tld>' /var/log/mail/mail.log | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
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
  run docker exec mail sasldblistusers2
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "user1@localhost.localdomain: userPassword" ]
  [ "${lines[1]}" = "user2@otherdomain.tld: userPassword" ]
}

@test "checking accounts: user mail folders for user1" {
  run docker exec mail ls -A /var/mail/localhost.localdomain/user1
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = ".Drafts" ]
  [ "${lines[1]}" = ".Sent" ]
  [ "${lines[2]}" = ".Trash" ]
  [ "${lines[3]}" = "courierimapsubscribed" ]
  [ "${lines[4]}" = "cur" ]
  [ "${lines[5]}" = "new" ]
  [ "${lines[6]}" = "tmp" ]
}

@test "checking accounts: user mail folders for user2" {
  run docker exec mail ls -A /var/mail/otherdomain.tld/user2
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = ".Drafts" ]
  [ "${lines[1]}" = ".Sent" ]
  [ "${lines[2]}" = ".Trash" ]
  [ "${lines[3]}" = "courierimapsubscribed" ]
  [ "${lines[4]}" = "cur" ]
  [ "${lines[5]}" = "new" ]
  [ "${lines[6]}" = "tmp" ]
}

#
# postfix
#

@test "checking postfix: vhost file is correct" {
  run docker exec mail cat /etc/postfix/vhost
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "localhost.localdomain" ]
  [ "${lines[1]}" = "otherdomain.tld" ]
}

@test "checking postfix: main.cf overrides" {
  run docker exec mail grep -q 'max_idle = 600s' /tmp/postfix/main.cf
  [ "$status" -eq 0 ]
  run docker exec mail grep -q 'readme_directory = /tmp' /tmp/postfix/main.cf
  [ "$status" -eq 0 ]
}

#
# spamassassin
#

@test "checking spamassassin: docker env variables are set correctly (default)" {
  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  [ "$status" -eq 0 ]
  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  [ "$status" -eq 0 ]
  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  [ "$status" -eq 0 ]
}

@test "checking spamassassin: docker env variables are set correctly (custom)" {
  run docker exec mail /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 1.0'"
  [ "$status" -eq 0 ]
  run docker exec mail /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  [ "$status" -eq 0 ]
  run docker exec mail /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 3.0'"
  [ "$status" -eq 0 ]
}

#
# opendkim
#

@test "checking opendkim: /etc/opendkim/KeyTable should contain 2 entries" {
  run docker exec mail /bin/sh -c "cat /etc/opendkim/KeyTable | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

@test "checking opendkim: /etc/opendkim/keys/ should contain 2 entries" {
  run docker exec mail /bin/sh -c "ls -l /etc/opendkim/keys/ | grep '^d' | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

#
# opendmarc
#

@test "checking opendkim: server fqdn should be added to /etc/opendmarc.conf as AuthservID" {
  run docker exec mail grep ^AuthservID /etc/opendmarc.conf
  [ "$status" -eq 0 ]
  [ "$output" = "AuthservID mail.my-domain.com" ]
}

@test "checking opendkim: server fqdn should be added to /etc/opendmarc.conf as TrustedAuthservIDs" {
  run docker exec mail grep ^TrustedAuthservID /etc/opendmarc.conf
  [ "$status" -eq 0 ]
  [ "$output" = "TrustedAuthservIDs mail.my-domain.com" ]
}

#
# letsencrypt
#

@test "checking letsencrypt: lets-encrypt-x1-cross-signed.pem is installed" {
  run docker exec mail grep 'BEGIN CERTIFICATE' /etc/ssl/certs/lets-encrypt-x1-cross-signed.pem
  [ "$status" -eq 0 ]
}

@test "checking letsencrypt: lets-encrypt-x2-cross-signed.pem is installed" {
  run docker exec mail grep 'BEGIN CERTIFICATE' /etc/ssl/certs/lets-encrypt-x2-cross-signed.pem
  [ "$status" -eq 0 ]
}

#
# ssl
#

@test "checking ssl: generated default cert is installed" {
  run docker exec mail /bin/sh -c "openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 0 (ok)'"
  [ "$status" -eq 0 ]
}

#
# fail2ban
#

@test "checking fail2ban: localhost is not banned" {
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status sasl | grep 'IP list:.*127.0.0.1'"
  [ "$status" -eq 1 ]
}

@test "checking fail2ban: ban ip on multiple failed login" {
  docker exec mail_fail2ban fail2ban-client status sasl
  docker exec mail_fail2ban fail2ban-client set sasl delignoreip 127.0.0.1/8
  docker exec mail_fail2ban /bin/sh -c 'nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-login-wrong.txt'
  docker exec mail_fail2ban /bin/sh -c 'nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-login-wrong.txt'
  docker exec mail_fail2ban /bin/sh -c 'nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-login-wrong.txt'
  sleep 5
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status sasl | grep 'IP list:.*127.0.0.1'"
  [ "$status" -eq 0 ]
}

@test "checking fail2ban: unban ip works" {
  docker exec mail_fail2ban fail2ban-client set sasl addignoreip 127.0.0.1/8
  docker exec mail_fail2ban fail2ban-client set sasl unbanip 127.0.0.1
  sleep 5
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status sasl | grep 'IP list:.*127.0.0.1'"
  [ "$status" -eq 1 ]
}

#
# system
#

@test "checking system: freshclam cron is enabled" {
  run docker exec mail crontab -l
  [ "$status" -eq 0 ]
  [ "$output" = "0 1 * * * /usr/bin/freshclam --quiet" ]
}

@test "checking system: /var/log/mail/mail.log is error free" {
  run docker exec mail grep 'non-null host address bits in' /var/log/mail/mail.log
  [ "$status" -eq 1 ]
  run docker exec mail grep ': error:' /var/log/mail/mail.log
  [ "$status" -eq 1 ]
  run docker exec mail_pop3 grep 'non-null host address bits in' /var/log/mail/mail.log
  [ "$status" -eq 1 ]
  run docker exec mail_pop3 grep ': error:' /var/log/mail/mail.log
  [ "$status" -eq 1 ]
}

@test "checking system: sets the server fqdn" {
  run docker exec mail hostname
  [ "$status" -eq 0 ]
  [ "$output" = "mail.my-domain.com" ]
}

@test "checking system: sets the server domain name in /etc/mailname" {
  run docker exec mail cat /etc/mailname
  [ "$status" -eq 0 ]
  [ "$output" = "my-domain.com" ]
}
