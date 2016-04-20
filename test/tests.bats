#
# processes
#

@test "checking process: postfix" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/postfix/master'"
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

#
# imap
#

@test "checking process: dovecot imaplogin (enabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  [ "$status" -eq 0 ]
}

@test "checking process: dovecot imaplogin (disabled using SMTP_ONLY)" {
  run docker exec mail_smtponly /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  [ "$status" -eq 1 ]
}

@test "checking imap: server is ready with STARTTLS" {
  run docker exec mail /bin/bash -c "nc -w 5 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'ready'"
  [ "$status" -eq 0 ]
}

@test "checking imap: authentication works" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-auth.txt"
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
  run docker exec mail_pop3 /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/pop3-auth.txt"
  [ "$status" -eq 0 ]
}

#
# sasl
#

@test "checking sasl: doveadm auth test works with good password" {
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld mypassword | grep 'auth succeeded'"
  [ "$status" -eq 0 ]
}

@test "checking sasl: doveadm auth test fails with bad password" {
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld BADPASSWORD | grep 'auth failed'"
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
  [ "${lines[0]}" = "localhost.localdomain" ]
  [ "${lines[1]}" = "otherdomain.tld" ]
}

@test "checking postfix: main.cf overrides" {
  run docker exec mail grep -q 'max_idle = 600s' /tmp/docker-mailserver/postfix-main.cf
  [ "$status" -eq 0 ]
  run docker exec mail grep -q 'readme_directory = /tmp' /tmp/docker-mailserver/postfix-main.cf
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

@test "checking opendkim: generator creates keys, tables and TrustedHosts" {
  run docker run --rm \
  -v "$(pwd)/test/config/empty/":/tmp/docker-mailserver/ \
  -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
  -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
  -ti tvial/docker-mailserver:v2 generate-dkim-config | wc -l
  [ "$status" -eq 0 ]
  [ "$output" -eq 5 ]
  rm -rf "$(pwd)/test/config/empty" && mkdir -p "$(pwd)/test/config/empty"
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

@test "checking fail2ban: localhost is not banned because ignored" {
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status sasl | grep 'IP list:.*127.0.0.1'"
  [ "$status" -eq 1 ]
  run docker exec mail_fail2ban /bin/sh -c "grep 'ignoreip = 127.0.0.1/8' /etc/fail2ban/jail.conf"
  [ "$status" -eq 0 ]
}

@test "checking fail2ban: ban ip on multiple failed login" {
  # Getting mail_fail2ban container IP
  MAIL_FAIL2BAN_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mail_fail2ban)
  # Create a container which will send wront authentications and should banned
  docker run --name fail-auth-mailer -e MAIL_FAIL2BAN_IP=$MAIL_FAIL2BAN_IP -v "$(pwd)/test":/tmp/docker-mailserver-test -d tvial/docker-mailserver:v2 tail -f /var/log/faillog
  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'
  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'
  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'
  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'
  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'
  sleep 5
  # Checking that FAIL_AUTH_MAILER_IP is banned in mail_fail2ban
  FAIL_AUTH_MAILER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' fail-auth-mailer)
  run docker exec mail_fail2ban /bin/sh -c "export FAIL_AUTH_MAILER_IP=$FAIL_AUTH_MAILER_IP && fail2ban-client status sasl | grep '$FAIL_AUTH_MAILER_IP'"
  [ "$status" -eq 0 ]
}

@test "checking fail2ban: unban ip works" {
  FAIL_AUTH_MAILER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' fail-auth-mailer)
  docker exec mail_fail2ban fail2ban-client set sasl unbanip $FAIL_AUTH_MAILER_IP
  sleep 5
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status sasl | grep 'IP list:.*$FAIL_AUTH_MAILER_IP'"
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
