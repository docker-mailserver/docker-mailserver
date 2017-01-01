load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

#
# configuration checks
#

@test "checking configuration: hostname/domainname" {
  run docker run `docker inspect --format '{{ .Config.Image }}' mail`
  assert_failure
}

#
# processes
#

@test "checking process: postfix" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/postfix/master'"
  assert_success
}

@test "checking process: amavisd-new" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/amavisd-new'"
  assert_success
}

@test "checking process: opendkim" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/opendkim'"
  assert_success
}

@test "checking process: opendmarc" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/opendmarc'"
  assert_success
}

@test "checking process: clamav (disabled by ENABLE_CLAMAV=0)" {
  if [ $ENABLE_CLAMAV -eq 0 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
    assert_failure
  elif [ $ENABLE_CLAMAV -eq 1 ]; then
    skip
  fi
}

@test "checking process: clamav (enabled by ENABLE_CLAMAV=1)" {
  if [ $ENABLE_CLAMAV -eq 0 ]; then
    skip
  elif [ $ENABLE_CLAMAV -eq 1 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
    assert_success
  fi
}

@test "checking process: fail2ban (disabled by ENABLE_FAIL2BAN=0)" {
  if [ $ENABLE_FAIL2BAN -eq 0 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/python /usr/bin/fail2ban-server'"
    assert_failure
  elif [ $ENABLE_FAIL2BAN -eq 1 ]; then
    skip
  fi
}

@test "checking process: fail2ban (enabled by ENABLE_FAIL2BAN=1)" {
  if [ $ENABLE_FAIL2BAN -eq 0 ]; then
    skip
  elif [ $ENABLE_FAIL2BAN -eq 1 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/python /usr/bin/fail2ban-server'"
    assert_success
  fi
}

@test "checking process: fetchmail (disabled by ENABLE_FETCHMAIL=0)" {
  if [ $ENABLE_FETCHMAIL -eq 0 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
    assert_failure
  elif [ $ENABLE_FETCHMAIL -eq 1 ]; then
    skip
  fi
}

@test "checking process: fetchmail (enabled by ENABLE_FETCHMAIL=1)" {
  if [ $ENABLE_FETCHMAIL -eq 0 ]; then
    skip
  elif [ $ENABLE_FETCHMAIL -eq 1 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
    assert_success
  fi
}

@test "checking process: saslauthd (disabled by ENABLE_SASLAUTHD=0)" {
  if [ $ENABLE_SASLAUTHD -eq 0 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
    assert_failure
  elif [ $ENABLE_SASLAUTHD -eq 1 ]; then
    skip
  fi
}

@test "checking process: saslauthd (enabled by ENABLE_SASLAUTHD=1)" {
  if [ $ENABLE_SASLAUTHD -eq 0 ]; then
    skip
  elif [ $ENABLE_SASLAUTHD -eq 1 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
    assert_success
  fi
}

#
# imap
#

@test "checking process: dovecot imaplogin (enabled in default configuration)" {
  if [ $SMTP_ONLY -eq 0 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
    assert
  elif [ $SMTP_ONLY -eq 1 ]; then
    skip
  fi
}

@test "checking process: dovecot imaplogin (disabled using SMTP_ONLY)" {
  if [ $SMTP_ONLY -eq 0 ]; then
    skip  
  elif [ $SMTP_ONLY -eq 1 ]; then
    run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
    assert_failure
  fi
}

@test "checking imap: server is ready with STARTTLS" {
  if [ $SMTP_ONLY -eq 1 ]; then
    skip
  fi
  run docker exec mail /bin/bash -c "nc -w 2 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'ready'"
  assert_success
}

@test "checking imap: authentication works" {
  if [ $SMTP_ONLY -eq 1 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-auth.txt"
  assert_success
}

#
# pop
#

@test "checking pop: server is ready" {
  if [ $ENABLE_POP3 -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/bash -c "nc -w 1 0.0.0.0 110 | grep '+OK'"
  assert_success
}

@test "checking pop: authentication works" {
  if [ $ENABLE_POP3 -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/pop3-auth.txt"
  assert_success
}

#
# sasl
#

@test "checking sasl: doveadm auth test works with good password" {
  if [ -z $SASL_PASSWD ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld mypassword | grep 'auth succeeded'"
  assert_success
}

@test "checking sasl: doveadm auth test fails with bad password" {
  if [ -z $SASL_PASSWD ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld BADPASSWORD | grep 'auth failed'"
  assert_success
}

@test "checking sasl: sasl_passwd exists" {
  if [ -z $SASL_PASSWD ]; then
    skip
  fi
  run docker exec mail [ -f /etc/postfix/sasl_passwd ]
  assert_success
}

#
# logs
#

@test "checking logs: mail related logs should be located in a subdirectory" {
  run docker exec mail /bin/sh -c "ls -1 /var/log/mail/ | grep -E 'clamav|freshclam|mail'|wc -l"
  assert
  [ "$output" -ge 3 ]
}

#
# smtp
#

@test "checking smtp: authentication works with good password (plain)" {
  run docker exec mail /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-plain.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking smtp: authentication fails with wrong password (plain)" {
  run docker exec mail /bin/sh -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-plain-wrong.txt | grep 'authentication failed'"
  assert_success
}

@test "checking smtp: authentication works with good password (login)" {
  run docker exec mail /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking smtp: authentication fails with wrong password (login)" {
  run docker exec mail /bin/sh -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt | grep 'authentication failed'"
  assert_success
}

@test "checking smtp: delivers mail to existing accounts" {
  run docker exec mail /bin/sh -c "grep 'postfix/lmtp' /var/log/mail/mail.log | grep 'status=sent' | grep ' Saved)' | wc -l"
  emails_received = 6
  # An additional email is received if spam are not filtered
  if [ $ENABLE_CLAMAV -eq 0 ]; then
    emails_received = $emails_received+1
  fi
  # An additional email is received if virus are not filtered
  if [ $ENABLE_SPAMASSASSIN -eq 0 ]; then
    emails_received = $emails_received+1
  fi
  assert_output $emails_received
}

@test "checking smtp: delivers mail to existing alias" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<alias1@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_output 1
}

@test "checking smtp: delivers mail to existing catchall" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<wildcard@localdomain2.com>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_output 1
}

@test "checking smtp: delivers mail to regexp alias" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<test123@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_output 1
}

@test "checking smtp: user1 should have received a defined number of mails" {
  run docker exec mail /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l"
  emails_received = 5
  # An additional email is received if spam are not filtered
  if [ $ENABLE_CLAMAV -eq 0 ]; then
    emails_received = $emails_received+1
  fi
  # An additional email is received if virus are not filtered
  if [ $ENABLE_SPAMASSASSIN -eq 0 ]; then
    emails_received = $emails_received+1
  fi
  assert_output $emails_received
}

@test "checking smtp: rejects mail to unknown user" {
  run docker exec mail /bin/sh -c "grep '<nouser@localhost.localdomain>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail/mail.log | wc -l"
  assert_output 1
}

@test "checking smtp: redirects mail to external aliases" {
  run docker exec mail /bin/sh -c "grep -- '-> <external1@otherdomain.tld>' /var/log/mail/mail.log | wc -l"
  assert_output 2
}

@test "checking smtp: rejects spam" {
  if [ $ENABLE_SPAMASSASSIN -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep 'Blocked SPAM' /var/log/mail/mail.log | wc -l"
  assert_output 1
}

@test "checking smtp: rejects virus" {
  if [ $ENABLE_CLAMAV -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep 'Blocked INFECTED' /var/log/mail/mail.log | wc -l"
  assert_output 1
}

#
# accounts
#

@test "checking accounts: user accounts" {
  run docker exec mail doveadm user '*'
  assert_success
  [ "${lines[0]}" = "user1@localhost.localdomain" ]
  [ "${lines[1]}" = "user2@otherdomain.tld" ]
}

@test "checking accounts: user mail folders for user1" {
  run docker exec mail /bin/bash -c "ls -A /var/mail/localhost.localdomain/user1 | grep -E '.Drafts|.Sent|.Trash|cur|new|subscriptions|tmp' | wc -l"
  assert_output 7
}

@test "checking accounts: user mail folders for user2" {
  run docker exec mail /bin/bash -c "ls -A /var/mail/otherdomain.tld/user2 | grep -E '.Drafts|.Sent|.Trash|cur|new|subscriptions|tmp' | wc -l"
  assert_output 7
}

#
# postfix
#

@test "checking postfix: vhost file is correct" {
  run docker exec mail cat /etc/postfix/vhost
  assert_success
  [ "${lines[0]}" = "localdomain2.com" ]
  [ "${lines[1]}" = "localhost.localdomain" ]
  [ "${lines[2]}" = "otherdomain.tld" ]
}

@test "checking postfix: main.cf overrides" {
  run docker exec mail grep -q 'max_idle = 600s' /tmp/docker-mailserver/postfix-main.cf
  assert_success
  run docker exec mail grep -q 'readme_directory = /tmp' /tmp/docker-mailserver/postfix-main.cf
  assert_success
}

#
# dovecot
#

@test "checking dovecot: config additions" {
  run docker exec mail grep -q 'mail_max_userip_connections = 69' /tmp/docker-mailserver/dovecot.cf
  assert_success
  run docker exec mail /bin/sh -c "doveconf | grep 'mail_max_userip_connections = 69'"
  assert_output 'mail_max_userip_connections = 69'
}

#
# spamassassin
#

@test "checking spamassassin: should be listed in amavis when enabled" {
  if [ $ENABLE_SPAMASSASSIN -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep -i 'ANTI-SPAM-SA code' /var/log/mail/mail.log | grep 'NOT loaded'"
  assert_failure
}

@test "checking spamassassin: should not be listed in amavis when disabled" {
  if [ $ENABLE_SPAMASSASSIN -eq 1 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep -i 'ANTI-SPAM-SA code' /var/log/mail/mail.log | grep 'NOT loaded'"
  assert_success
}

@test "checking spamassassin: docker env variables are set correctly (default)" {
  if [ ! -z $SA_TAG -a ! -z $SA_TAG2 -a ! -z $SA_KILL ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  assert_success
  run docker exec mail /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  assert_success
  run docker exec mail /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  assert_success
}

@test "checking spamassassin: docker env variables are set correctly (custom)" {
  if [ -z $SA_TAG -a -z $SA_TAG2 -a -z $SA_KILL ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 1.0'"
  assert_success
  run docker exec mail /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  assert_success
  run docker exec mail /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 3.0'"
  assert_success
}

#
# clamav
#

@test "checking clamav: should be listed in amavis when enabled" {
  if [ $ENABLE_CLAMAV -eq 0 ]; then
    skip
  fi
  run docker exec mail grep -i 'Found secondary av scanner ClamAV-clamscan' /var/log/mail/mail.log
  assert_success
}

@test "checking clamav: should not be listed in amavis when disabled" {
  if [ $ENABLE_CLAMAV -eq 1 ]; then
    skip
  fi
  run docker exec mail grep -i 'Found secondary av scanner ClamAV-clamscan' /var/log/mail/mail.log
  assert_failure
}

@test "checking clamav: should not be called when disabled" {
  if [ $ENABLE_CLAMAV -eq 1 ]; then
    skip
  fi
  run docker exec mail grep -i 'connect to /var/run/clamav/clamd.ctl failed' /var/log/mail/mail.log
  assert_failure
}

#
# opendkim
#

@test "checking opendkim: /etc/opendkim/KeyTable should contain 2 entries" {
  run docker exec mail /bin/sh -c "cat /etc/opendkim/KeyTable | wc -l"
  assert_output 2
}

@test "checking opendkim: /etc/opendkim/keys/ should contain 2 entries" {
  run docker exec mail /bin/sh -c "ls -l /etc/opendkim/keys/ | grep '^d' | wc -l"
  assert_output 2
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts" {
  rm -rf "$(pwd)/test/config/empty" && mkdir -p "$(pwd)/test/config/empty"
  run docker run --rm \
    -v "$(pwd)/test/config/empty/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  assert_output 6
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_output 2
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  assert_output 2
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_output 4
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts without postfix-accounts.cf" {
  rm -rf "$(pwd)/test/config/without-accounts" && mkdir -p "$(pwd)/test/config/without-accounts"
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  assert_output 5
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_output 2
  # Check keys for otherdomain.tld
  # run docker run --rm \
  #   -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
  #   `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  # assert
  # [ "$output" -eq 0 ]
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_output 4
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts without postfix-virtual.cf" {
  rm -rf "$(pwd)/test/config/without-virtual" && mkdir -p "$(pwd)/test/config/without-virtual"
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  assert_output 5
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_output 2
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  assert_output 2
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_output 4
}

#
# ssl
#

@test "checking ssl: generated default cert works correctly" {
  if [ ! -z $SSL_TYPE ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 0 (ok)'"
  assert_success
}

@test "checking ssl: lets-encrypt-x3-cross-signed.pem is installed" {
  run docker exec mail grep 'BEGIN CERTIFICATE' /etc/ssl/certs/lets-encrypt-x3-cross-signed.pem
  assert_success
}

@test "checking ssl: letsencrypt configuration is correct" {
  if [ $SSL_TYPE = "letsencrypt" ]; then
    run docker exec mail /bin/sh -c 'grep -ir "/etc/letsencrypt/live/mail.my-domain.com/" /etc/postfix/main.cf | wc -l'
    assert_output 2
    run docker exec mail /bin/sh -c 'grep -ir "/etc/letsencrypt/live/mail.my-domain.com/" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
    assert_output 2
  else 
    skip
  fi
}

@test "checking ssl: letsencrypt cert works correctly" {
  if [ $SSL_TYPE = "letsencrypt" ]; then
    run docker exec mail /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
    assert_success
  else
    skip
  fi
}

@test "checking ssl: manual configuration is correct" {
  if [ $SSL_TYPE = "manual" ]; then
    run docker exec mail /bin/sh -c 'grep -ir "/etc/postfix/ssl/cert" /etc/postfix/main.cf | wc -l'
    assert_output 1
    run docker exec mail /bin/sh -c 'grep -ir "/etc/postfix/ssl/cert" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
    assert_output 1
    run docker exec mail /bin/sh -c 'grep -ir "/etc/postfix/ssl/key" /etc/postfix/main.cf | wc -l'
    assert_output 1
    run docker exec mail /bin/sh -c 'grep -ir "/etc/postfix/ssl/key" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
    assert_output 1
  else
    skip
  fi
}

@test "checking ssl: manual configuration copied files correctly " {
  if [ $SSL_TYPE = "manual" ]; then
    run docker exec mail /bin/sh -c 'cmp -s /etc/postfix/ssl/cert /tmp/docker-mailserver/letsencrypt/mail.my-domain.com/fullchain.pem'
    assert_success
    run docker exec mail /bin/sh -c 'cmp -s /etc/postfix/ssl/key /tmp/docker-mailserver/letsencrypt/mail.my-domain.com/privkey.pem'
    assert_success
  else
    skip
  fi
}

@test "checking ssl: manual cert works correctly" {
  if [ $SSL_TYPE = "manual" ]; then
    run docker exec mail /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
    assert_success
  else
    skip
  fi
}

#
# fail2ban
#

@test "checking fail2ban: localhost is not banned because ignored" {
  if [ $ENABLE_FAIL2BAN -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "fail2ban-client status postfix-sasl | grep 'IP list:.*127.0.0.1'"
  assert_failure
  run docker exec mail /bin/sh -c "grep 'ignoreip = 127.0.0.1/8' /etc/fail2ban/jail.conf"
  assert
}

@test "checking fail2ban: fail2ban-jail.cf overrides" {
  if [ $ENABLE_FAIL2BAN -eq 0 ]; then
    skip
  fi
  FILTERS=(sshd postfix dovecot postfix-sasl)

  for FILTER in "${FILTERS[@]}"; do
    run docker exec mail /bin/sh -c "fail2ban-client get $FILTER bantime"
    assert_output 1234

    run docker exec mail /bin/sh -c "fail2ban-client get $FILTER findtime"
    assert_output 321

    run docker exec mail /bin/sh -c "fail2ban-client get $FILTER maxretry"
    assert_output 2
  done
}

@test "checking fail2ban: ban ip on multiple failed login" {
  if [ $ENABLE_FAIL2BAN -eq 0 ]; then
    skip
  fi
  # Getting mail_fail2ban container IP
  MAIL_FAIL2BAN_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mail)

  # Create a container which will send wrong authentications and should banned
  docker run --name fail-auth-mailer -e MAIL_FAIL2BAN_IP=$MAIL_FAIL2BAN_IP -v "$(pwd)/test":/tmp/docker-mailserver-test -d $(docker inspect --format '{{ .Config.Image }}' mail) tail -f /var/log/faillog

  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'
  docker exec fail-auth-mailer /bin/sh -c 'nc $MAIL_FAIL2BAN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt'

  sleep 5

  # Checking that FAIL_AUTH_MAILER_IP is banned in mail_fail2ban
  FAIL_AUTH_MAILER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' fail-auth-mailer)

  run docker exec mail /bin/sh -c "fail2ban-client status postfix-sasl | grep '$FAIL_AUTH_MAILER_IP'"
  assert_success

  # Checking that FAIL_AUTH_MAILER_IP is banned by iptables
  run docker exec mail /bin/sh -c "iptables -L f2b-postfix-sasl -n | grep REJECT | grep '$FAIL_AUTH_MAILER_IP'"
  assert_success
}

@test "checking fail2ban: unban ip works" {
  if [ $ENABLE_FAIL2BAN -eq 0 ]; then
    skip
  fi
  FAIL_AUTH_MAILER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' fail-auth-mailer)

  docker exec mail fail2ban-client set postfix-sasl unbanip $FAIL_AUTH_MAILER_IP

  sleep 5

  run docker exec mail /bin/sh -c "fail2ban-client status postfix-sasl | grep 'IP list:.*$FAIL_AUTH_MAILER_IP'"
  assert_failure

  # Checking that FAIL_AUTH_MAILER_IP is unbanned by iptables
  run docker exec mail /bin/sh -c "iptables -L f2b-postfix-sasl -n | grep REJECT | grep '$FAIL_AUTH_MAILER_IP'"
  assert_failure
}

#
# fetchmail
#

@test "checking fetchmail: general options in fetchmailrc are loaded" {
  if [ $ENABLE_FETCHMAIL -eq 0 ]; then
    skip
  fi
  run docker exec mail grep 'set syslog' /etc/fetchmailrc
  assert_success
}

@test "checking fetchmail: fetchmail.cf is loaded" {
  if [ $ENABLE_FETCHMAIL -eq 0 ]; then
    skip
  fi
  run docker exec mail grep 'pop3.example.tld' /etc/fetchmailrc
  assert_success
}

#
# system
#

@test "checking system: freshclam cron is enabled" {
  run docker exec mail bash -c "crontab -l | grep '/usr/bin/freshclam'"
  assert_success
}

@test "checking amavis: virusmail wiper cron exists" {
  run docker exec mail bash -c "crontab -l | grep '/var/lib/amavis/virusmails/'"
  assert_success
}

@test "checking amavis: VIRUSMAILS_DELETE_DELAY override works as expected" {
  run docker run -ti --rm -e VIRUSMAILS_DELETE_DELAY=2 `docker inspect --format '{{ .Config.Image }}' mail` /bin/bash -c 'echo $VIRUSMAILS_DELETE_DELAY | grep 2' 
  assert_success
}

@test "checking amavis: old virusmail is wipped by cron" {
  docker exec mail bash -c 'touch -d "`date --date=2000-01-01`" /var/lib/amavis/virusmails/should-be-deleted'
  run docker exec -ti mail bash -c 'find /var/lib/amavis/virusmails/ -type f -mtime +$VIRUSMAILS_DELETE_DELAY -delete'
  assert_success
  run docker exec mail bash -c 'ls -la /var/lib/amavis/virusmails/ | grep should-be-deleted'
  assert_failure
}

@test "checking amavis: recent virusmail is not wipped by cron" {
  docker exec mail bash -c 'touch -d "`date`"  /var/lib/amavis/virusmails/should-not-be-deleted'
  run docker exec -ti mail bash -c 'find /var/lib/amavis/virusmails/ -type f -mtime +$VIRUSMAILS_DELETE_DELAY -delete'
  assert_success
  run docker exec mail bash -c 'ls -la /var/lib/amavis/virusmails/ | grep should-not-be-deleted'
  assert_success
}

@test "checking system: /var/log/mail/mail.log is error free" {
  run docker exec mail grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure
  run docker exec mail grep 'mail system configuration error' /var/log/mail/mail.log
  assert_failure
  run docker exec mail grep ': error:' /var/log/mail/mail.log
  assert_failure
  run docker exec mail grep -i 'is not writable' /var/log/mail/mail.log
  assert_failure
  run docker exec mail grep -i 'permission denied' /var/log/mail/mail.log
  assert_failure
  run docker exec mail grep -i '(!)connect' /var/log/mail/mail.log
  assert_failure
  run docker exec mail grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure
}

@test "checking system: /var/log/auth.log is error free" {
  run docker exec mail grep 'Unable to open env file: /etc/default/locale' /var/log/auth.log
  assert_failure
}

@test "checking system: sets the server fqdn" {
  run docker exec mail hostname
  assert_output "mail.my-domain.com"
}

@test "checking system: sets the server domain name in /etc/mailname" {
  run docker exec mail cat /etc/mailname
  assert_output "my-domain.com"
}

@test "checking system: postfix should not log to syslog" {
  run docker exec mail grep 'postfix' /var/log/syslog
  assert_failure
}

#
# sieve
#

@test "checking sieve: user1 should have received 1 email in folder INBOX.spam" {
  if [ $ENABLE_MANAGESIEVE -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/.INBOX.spam/new | wc -l"
  assert_output 1
}

@test "checking manage sieve: server is ready when ENABLE_MANAGESIEVE has been set" {
  if [ $ENABLE_MANAGESIEVE -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/bash -c "nc -z 0.0.0.0 4190"
  assert_success
}

@test "checking manage sieve: disabled per default" {
  if [ $ENABLE_MANAGESIEVE -eq 1 ]; then
    skip
  fi
  run docker exec mail /bin/bash -c "nc -z 0.0.0.0 4190"
  assert_failure
}

#
# accounts
#

@test "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser user3@domain.tld mypassword"

  run docker exec mail /bin/sh -c "grep '^user3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [ ! -z "$output" ]
}

@test "checking accounts: auser3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser auser3@domain.tld mypassword"

  run docker exec mail /bin/sh -c "grep '^auser3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  [ "$status" -eq 0 ]
  [ ! -z "$output" ]
}

@test "checking accounts: a.ser3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser a.ser3@domain.tld mypassword"

  run docker exec mail /bin/sh -c "grep '^a\.ser3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  [ "$status" -eq 0 ]
  [ ! -z "$output" ]
}

@test "checking accounts: user3 should have been removed from /tmp/docker-mailserver/postfix-accounts.cf but not auser3" {
  docker exec mail /bin/sh -c "delmailuser user3@domain.tld"

  run docker exec mail /bin/sh -c "grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_failure

  run docker exec mail /bin/sh -c "grep '^auser3@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
}

@test "checking user updating password for user in /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser user4@domain.tld mypassword"

  initialpass=$(run docker exec mail /bin/sh -c "grep '^user4@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf")
  sleep 2
  docker exec mail /bin/sh -c "updatemailuser user4@domain.tld mynewpassword"
  sleep 2
  changepass=$(run docker exec mail /bin/sh -c "grep '^user4@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf")

  if [ initialpass != changepass ]; then
    status="0"
  else
    status="1"
  fi

  docker exec mail /bin/sh -c "delmailuser auser3@domain.tld"

  assert_success
}


@test "checking accounts: listmailuser" {
  run docker exec mail /bin/sh -c "listmailuser | head -n 1"
  assert_output "user1@localhost.localdomain"
}

@test "checking accounts: no error is generated when deleting a user if /tmp/docker-mailserver/postfix-accounts.cf is missing" {
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'delmailuser user3@domain.tld'
  assert_success
  [ -z "$output" ]
}

@test "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf even when that file does not exist" {
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'addmailuser user3@domain.tld mypassword'
  [ "$status" -eq 0 ]
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf'
  assert_success
  [ ! -z "$output" ]
}

#
# PERMIT_DOCKER mynetworks
#

@test "checking PERMIT_DOCKER: can get container ip" {
  run docker exec mail /bin/sh -c "ip addr show eth0 | grep 'inet ' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1 | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'"
  assert_success
}

@test "checking PERMIT_DOCKER: opendmarc/opendkim config" {
  run docker exec mail /bin/sh -c "cat /etc/opendmarc/ignore.hosts | grep '172.16.0.0/12'"
  assert_success
  run docker exec mail /bin/sh -c "cat /etc/opendkim/TrustedHosts | grep '172.16.0.0/12'"
  assert_success
}

@test "checking PERMIT_DOCKER: my network value" {
  run docker exec mail /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.0\.0/16'"
  assert_success
  run docker exec mail /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}/32'"
  assert_success
}

#
# amavis
#

@test "checking amavis: config overrides" {
  run docker exec mail /bin/sh -c "grep 'Test Verification' /etc/amavis/conf.d/50-user | wc -l"
  assert_output 1
}

#
# setup.sh
#

# CLI interface
@test "checking setup.sh: Without arguments: status 1, show help text" {
  run ./setup.sh
  assert_failure
  [ "${lines[0]}" = "Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]" ]
}
@test "checking setup.sh: Wrong arguments" {
  run ./setup.sh lol troll
  assert_failure
  [ "${lines[0]}" = "Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]" ]
}

# email
@test "checking setup.sh: setup.sh email add " {
  run ./setup.sh -c mail email add lorem@impsum.org dolorsit
  assert_success
  value=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $1}')
  [ "$value" = "lorem@impsum.org" ]
}
@test "checking setup.sh: setup.sh email list" {
  run ./setup.sh -c mail email list
  assert_success
}
@test "checking setup.sh: setup.sh email update" {
	initialpass=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $2}')
	run ./setup.sh -c mail email update lorem@impsum.org consectetur
	updatepass=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $2}')
	if [ initialpass != changepass ]; then
      status="0"
    else
      status="1"
    fi
	assert_success
}
@test "checking setup.sh: setup.sh email del" {
  run ./setup.sh -c mail email del lorem@impsum.org
  assert_success
  run value=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org)
  [ -z "$value" ]
}

# config
@test "checking setup.sh: setup.sh config dkim" {
  run ./setup.sh -c mail config dkim
  assert_success
}
# TODO: To create a test generate-ssl-certificate must be non interactive
#@test "checking setup.sh: setup.sh config ssl" {
#  run ./setup.sh -c mail_ssl config ssl
#  assert_success
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
  assert_success
  [ "${lines[0]}" = "Image: tvial/docker-mailserver:testing" ]
  [ "${lines[1]}" = "Container: mail" ]
}
@test "checking setup.sh: setup.sh debug login ls" {
  run ./setup.sh -c mail debug login ls
  assert_success
}

#
# LDAP
#

# postfix
@test "checking postfix: ldap lookup works correctly" {
  if [ $ENABLE_LDAP -eq 0 ]; then
    skip
  fi

  run docker exec mail /bin/sh -c "postmap -q some.user@localhost.localdomain ldap:/etc/postfix/ldap-users.cf"
  assert_output "some.user@localhost.localdomain"

  run docker exec mail /bin/sh -c "postmap -q postmaster@localhost.localdomain ldap:/etc/postfix/ldap-aliases.cf"
  assert_output "some.user@localhost.localdomain"

  run docker exec mail /bin/sh -c "postmap -q employees@localhost.localdomain ldap:/etc/postfix/ldap-groups.cf"
  assert_output "some.user@localhost.localdomain"
}

# dovecot
@test "checking dovecot: ldap imap connection and authentication works" {
  if [ $ENABLE_LDAP -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-ldap-auth.txt"
  assert_success
}

@test "checking dovecot: mail delivery works" {
  if [ $ENABLE_LDAP -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "sendmail -f user@external.tld some.user@localhost.localdomain < /tmp/docker-mailserver-test/email-templates/test-email.txt"
  sleep 10
  run docker exec mail /bin/sh -c "ls -A /var/mail/localhost.localdomain/some.user/new | wc -l"
  assert_output 1
}

# saslauthd
@test "checking saslauthd: sasl ldap authentication works" {
  if [ $ENABLE_SASLAUTHD -eq 0 ]; then
    skip
  fi
  run docker exec mail bash -c "testsaslauthd -u some.user -p secret"
  assert_success
}

@test "checking saslauthd: ldap smtp authentication" {
  if [ $ENABLE_SASLAUTHD -eq 0 ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt | grep 'Authentication successful'"
  assert_success
}
