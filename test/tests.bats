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

@test "checking process: fetchmail (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  [ "$status" -eq 1 ]
}

@test "checking process: fetchmail (fetchmail server enabled)" {
  run docker exec mail_fetchmail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  [ "$status" -eq 0 ]
}

@test "checking process: amavis (amavis disabled by DISABLE_AMAVIS)" {
  run docker exec mail_disabled_amavis /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/amavisd-new'"
  [ "$status" -eq 1 ]
}

@test "checking process: clamav (clamav disabled by DISABLE_CLAMAV)" {
  run docker exec mail_disabled_clamav /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  [ "$status" -eq 1 ]
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
  run docker exec mail /bin/bash -c "nc -w 2 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'ready'"
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
  rm -rf "$(pwd)/test/config/empty" && mkdir -p "$(pwd)/test/config/empty"
  run docker run --rm \
    -v "$(pwd)/test/config/empty/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 6 ]
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 4 ]
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts without postfix-accounts.cf" {
  rm -rf "$(pwd)/test/config/without-accounts" && mkdir -p "$(pwd)/test/config/without-accounts"
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 5 ]
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  # Check keys for otherdomain.tld
  # run docker run --rm \
  #   -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
  #   `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  # [ "$status" -eq 0 ]
  # [ "$output" -eq 0 ]
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 4 ]
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts without postfix-virtual.cf" {
  rm -rf "$(pwd)/test/config/without-virtual" && mkdir -p "$(pwd)/test/config/without-virtual"
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 5 ]
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 4 ]
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
# ssl
#

@test "checking ssl: generated default cert works correctly" {
  run docker exec mail /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 0 (ok)'"
  [ "$status" -eq 0 ]
}

@test "checking ssl: lets-encrypt-x1-cross-signed.pem is installed" {
  run docker exec mail grep 'BEGIN CERTIFICATE' /etc/ssl/certs/lets-encrypt-x1-cross-signed.pem
  [ "$status" -eq 0 ]
}

@test "checking ssl: lets-encrypt-x2-cross-signed.pem is installed" {
  run docker exec mail grep 'BEGIN CERTIFICATE' /etc/ssl/certs/lets-encrypt-x2-cross-signed.pem
  [ "$status" -eq 0 ]
}

@test "checking ssl: letsencrypt configuration is correct" {
  run docker exec mail_pop3 /bin/sh -c 'grep -ir "/etc/letsencrypt/live/mail.my-domain.com/" /etc/postfix/main.cf | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  run docker exec mail_pop3 /bin/sh -c 'grep -ir "/etc/letsencrypt/live/mail.my-domain.com/" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

@test "checking ssl: letsencrypt cert works correctly" {
  run docker exec mail_pop3 /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  [ "$status" -eq 0 ]
}

@test "checking ssl: manual configuration is correct" {
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/cert" /etc/postfix/main.cf | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/cert" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/key" /etc/postfix/main.cf | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/key" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "checking ssl: manual configuration copied files correctly " {
  run docker exec mail_manual_ssl /bin/sh -c 'cmp -s /etc/postfix/ssl/cert /tmp/docker-mailserver/letsencrypt/mail.my-domain.com/fullchain.pem'
  [ "$status" -eq 0 ]
  run docker exec mail_manual_ssl /bin/sh -c 'cmp -s /etc/postfix/ssl/key /tmp/docker-mailserver/letsencrypt/mail.my-domain.com/privkey.pem'
  [ "$status" -eq 0 ]
}

@test "checking ssl: manual cert works correctly" {
  run docker exec mail_manual_ssl /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  [ "$status" -eq 0 ]
}

#
# fail2ban
#

@test "checking fail2ban: localhost is not banned because ignored" {
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status postfix-sasl | grep 'IP list:.*127.0.0.1'"
  [ "$status" -eq 1 ]
  run docker exec mail_fail2ban /bin/sh -c "grep 'ignoreip = 127.0.0.1/8' /etc/fail2ban/jail.conf"
  [ "$status" -eq 0 ]
}

@test "checking fail2ban: fail2ban-jail.cf overrides" {
  FILTERS=(sshd postfix dovecot postfix-sasl)

  for FILTER in "${FILTERS[@]}"; do
    run docker exec mail_fail2ban /bin/sh -c "fail2ban-client get $FILTER bantime"
    [ "$output" = 1234 ]

    run docker exec mail_fail2ban /bin/sh -c "fail2ban-client get $FILTER findtime"
    [ "$output" = 321 ]

    run docker exec mail_fail2ban /bin/sh -c "fail2ban-client get $FILTER maxretry"
    [ "$output" = 2 ]
  done
}

@test "checking fail2ban: ban ip on multiple failed login" {
  # Getting mail_fail2ban container IP
  MAIL_FAIL2BAN_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mail_fail2ban)

  # Create a container which will send wront authentications and should banned
  docker run --name fail-auth-mailer -e MAIL_FAIL2BAN_IP=$MAIL_FAIL2BAN_IP -v "$(pwd)/test":/tmp/docker-mailserver-test -d $(docker inspect --format '{{ .Config.Image }}' mail) tail -f /var/log/faillog

  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'
  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'

  sleep 5

  # Checking that FAIL_AUTH_MAILER_IP is banned in mail_fail2ban
  FAIL_AUTH_MAILER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' fail-auth-mailer)

  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status postfix-sasl | grep '$FAIL_AUTH_MAILER_IP'"
  [ "$status" -eq 0 ]

  # Checking that FAIL_AUTH_MAILER_IP is banned by iptables
  run docker exec mail_fail2ban /bin/sh -c "iptables -L f2b-postfix-sasl -n | grep REJECT | grep '$FAIL_AUTH_MAILER_IP'"
  [ "$status" -eq 0 ]
}

@test "checking fail2ban: unban ip works" {
  FAIL_AUTH_MAILER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' fail-auth-mailer)

  docker exec mail_fail2ban fail2ban-client set postfix-sasl unbanip $FAIL_AUTH_MAILER_IP

  sleep 5

  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status postfix-sasl | grep 'IP list:.*$FAIL_AUTH_MAILER_IP'"
  [ "$status" -eq 1 ]

  # Checking that FAIL_AUTH_MAILER_IP is unbanned by iptables
  run docker exec mail_fail2ban /bin/sh -c "iptables -L f2b-postfix-sasl -n | grep REJECT | grep '$FAIL_AUTH_MAILER_IP'"
  [ "$status" -eq 1 ]
}

#
# fetchmail
#

@test "checking fetchmail: gerneral options in fetchmailrc are loaded" {
  run docker exec mail_fetchmail grep 'set syslog' /etc/fetchmailrc
  [ "$status" -eq 0 ]
}

@test "checking fetchmail: fetchmail.cf is loaded" {
  run docker exec mail_fetchmail grep 'pop3.example.com' /etc/fetchmailrc
  [ "$status" -eq 0 ]
}

#
# system
#

@test "checking system: freshclam cron is enabled" {
  run docker exec mail crontab -l
  [ "$status" -eq 0 ]
  [ "$output" = "0 0,6,12,18 * * * /usr/bin/freshclam --quiet" ]
}

@test "checking system: /var/log/mail/mail.log is error free" {
  run docker exec mail grep 'non-null host address bits in' /var/log/mail/mail.log
  [ "$status" -eq 1 ]
  run docker exec mail grep 'mail system configuration error' /var/log/mail/mail.log
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

#
# sieve
#

@test "checking sieve: user1 should have received 1 email in folder INBOX.spam" {
  run docker exec mail /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/.INBOX.spam/new | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = 1 ]
}

@test "checking manage sieve: server is ready when ENABLE_MANAGESIEVE has been set" {
  run docker exec mail /bin/bash -c "nc -z 0.0.0.0 4190"
  [ "$status" -eq 0 ]
}

@test "checking manage sieve: disabled per default" {
  run docker exec mail_pop3 /bin/bash -c "nc -z 0.0.0.0 4190"
  [ "$status" -ne 0 ]
}

#
# accounts
#

@test "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser user3@domain.tld mypassword"

  run docker exec mail /bin/sh -c "grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf"
  [ "$status" -eq 0 ]
  [ ! -z "$output" ]
}

@test "checking accounts: user3 should have been removed from /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "delmailuser user3@domain.tld"

  run docker exec mail /bin/sh -c "grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "checking accounts: listmailuser" {
  run docker exec mail /bin/sh -c "listmailuser | head -n 1"
  [ "$status" -eq 0 ]
  [ "$output" = user1@localhost.localdomain ]
}

@test "checking accounts: no error is generated when deleting a user if /tmp/docker-mailserver/postfix-accounts.cf is missing" {
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'delmailuser user3@domain.tld'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf even when that file does not exist" {
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'addmailuser user3@domain.tld mypassword'
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf'
  [ "$status" -eq 0 ]
  [ ! -z "$output" ]
}

#
# PERMIT_DOCKER mynetworks
#

@test "checking PERMIT_DOCKER: can get container ip" {
  run docker exec mail /bin/sh -c "ip addr show eth0 | grep 'inet ' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1 | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'"
  [ "$status" -eq 0 ]
}

@test "checking PERMIT_DOCKER: opendmarc/opendkim config" {
  run docker exec mail_smtponly /bin/sh -c "cat /etc/opendmarc/ignore.hosts | grep '172.16.0.0/12'"
  [ "$status" -eq 0 ]
  run docker exec mail_smtponly /bin/sh -c "cat /etc/opendkim/TrustedHosts | grep '172.16.0.0/12'"
  [ "$status" -eq 0 ]
}

@test "checking PERMIT_DOCKER: my network value" {
  run docker exec mail /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.0\.0/16'"
  [ "$status" -eq 0 ]
  run docker exec mail_pop3 /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}/32'"
  [ "$status" -eq 0 ]
}

#
# amavis
#

@test "checking amavis: config overrides" {
  run docker exec mail /bin/sh -c "grep 'Test Verification' /etc/amavis/conf.d/50-user | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

#
# setup.sh
#

# CLI interface
@test "checking setup.sh: Without arguments: status 1, show help text" {
  run ./setup.sh
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]" ]
}
@test "checking setup.sh: Wrong arguments" {
  run ./setup.sh lol troll
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]" ]
}

# email
@test "checking setup.sh: setup.sh email add " {
  run ./setup.sh -c mail email add lorem@impsum.org dolorsit
  [ "$status" -eq 0 ]
  value=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $1}')
  [ "$value" = "lorem@impsum.org" ]
}
@test "checking setup.sh: setup.sh email list" {
  run ./setup.sh -c mail email list
  [ "$status" -eq 0 ]
}
@test "checking setup.sh: setup.sh email del" {
  run ./setup.sh -c mail email del lorem@impsum.org
  [ "$status" -eq 0 ]
  run value=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org)
  [ -z "$value" ]
}

# config
@test "checking setup.sh: setup.sh config dkim" {
  run ./setup.sh -c mail config dkim
  [ "$status" -eq 0 ]
}
# TODO: To create a test generate-ssl-certificate must be non interactive
#@test "checking setup.sh: setup.sh config ssl" {
#  run ./setup.sh -c mail_ssl config ssl
#  [ "$status" -eq 0 ]
#}

# debug
@test "checking setup.sh: setup.sh debug fetchmail" {
  run ./setup.sh -c mail debug fetchmail
  [ "$status" -eq 5 ]
# TODO: Fix output check
# [ "$output" = "fetchmail: no mailservers have been specified." ]
}
@test "checking setup.sh: setup.sh debug inspect" {
  run ./setup.sh -c mail debug inspect
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Image: tvial/docker-mailserver:testing" ]
  [ "${lines[1]}" = "Container: mail" ]
}
@test "checking setup.sh: setup.sh debug login ls" {
  run ./setup.sh -c mail debug login ls
  [ "$status" -eq 0 ]
}
