load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'


#
# shared functions
#

function wait_for_service() {
  containerName=$1
  serviceName=$2
  count=0
  while ! (docker exec $containerName /usr/bin/supervisorctl status $serviceName | grep RUNNING >/dev/null)
  do
    ((count++)) && ((count==30)) && break
    sleep 5
  done
  return $(docker exec $containerName /usr/bin/supervisorctl status $serviceName | grep RUNNING >/dev/null)
}

function count_processed_changes() {
  containerName=$1
  docker exec $containerName cat /var/log/supervisor/changedetector.log | grep "Update checksum" | wc -l
}

#
# configuration checks
#

@test "checking configuration: hostname/domainname" {
  run docker run `docker inspect --format '{{ .Config.Image }}' mail`
  assert_success
}

@test "checking configuration: hostname/domainname override: check container hostname is applied correctly" {
  run docker exec mail_override_hostname /bin/bash -c "hostname | grep unknown.domain.tld"
  assert_success
}

@test "checking configuration: hostname/domainname override: check overriden hostname is applied to all configs" {
  run docker exec mail_override_hostname /bin/bash -c "cat /etc/mailname | grep my-domain.com"
  assert_success
  run docker exec mail_override_hostname /bin/bash -c "postconf -n | grep mydomain | grep my-domain.com"
  assert_success
  run docker exec mail_override_hostname /bin/bash -c "postconf -n | grep myhostname | grep mail.my-domain.com"
  assert_success
  run docker exec mail_override_hostname /bin/bash -c "doveconf | grep hostname | grep mail.my-domain.com"
  assert_success
  run docker exec mail_override_hostname /bin/bash -c "cat /etc/opendmarc.conf | grep AuthservID | grep mail.my-domain.com"
  assert_success
  run docker exec mail_override_hostname /bin/bash -c "cat /etc/opendmarc.conf | grep TrustedAuthservIDs | grep mail.my-domain.com"
  assert_success
  run docker exec mail_override_hostname /bin/bash -c "cat /etc/amavis/conf.d/05-node_id | grep myhostname | grep mail.my-domain.com"
  assert_success
}

@test "checking configuration: hostname/domainname override: check hostname in postfix HELO message" {
  run docker exec mail_override_hostname /bin/bash -c "nc -w 1 0.0.0.0 25 | grep mail.my-domain.com"
  assert_success
}

@test "checking configuration: hostname/domainname override: check headers of received mail" {
  run docker exec mail_override_hostname /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l | grep 1"
  assert_success
  run docker exec mail_override_hostname /bin/sh -c "cat /var/mail/localhost.localdomain/user1/new/* | grep mail.my-domain.com"
  assert_success

  # test whether the container hostname is not found in received mail
  run docker exec mail_override_hostname /bin/sh -c "cat /var/mail/localhost.localdomain/user1/new/* | grep unknown.domain.tld"
  assert_failure
}

#
# processes
#

@test "checking process: postfix" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/postfix/sbin/master'"
  assert_success
}

@test "checking process: clamd" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_success
}

@test "checking process: new" {
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

@test "checking process: fail2ban (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/python3 /usr/bin/fail2ban-server'"
  assert_failure
}

@test "checking process: fetchmail (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  assert_failure
}

@test "checking process: clamav (clamav disabled by ENABLED_CLAMAV=0)" {
  run docker exec mail_disabled_clamav_spamassassin /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_failure
}

#
# imap
#

@test "checking process: dovecot imaplogin (enabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  assert_success
}

@test "checking imap: server is ready with STARTTLS" {
  run docker exec mail /bin/bash -c "nc -w 2 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'ready'"
  assert_success
}

@test "checking imap: authentication works" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-auth.txt"
  assert_success
}

@test "checking imap: added user authentication works" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/added-imap-auth.txt"
  assert_success
}

#
# sasl
#

@test "checking sasl: doveadm auth test works with good password" {
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld mypassword | grep 'auth succeeded'"
  assert_success
}

@test "checking sasl: doveadm auth test fails with bad password" {
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld BADPASSWORD | grep 'auth failed'"
  assert_success
}

@test "checking sasl: sasl_passwd exists" {
  run docker exec mail [ -f /etc/postfix/sasl_passwd ]
  assert_success
}

#
# logs
#

@test "checking logs: mail related logs should be located in a subdirectory" {
  run docker exec mail /bin/sh -c "ls -1 /var/log/mail/ | grep -E 'clamav|freshclam|mail.log'|wc -l"
  assert_success
  assert_output 3
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

@test "checking smtp: added user authentication works with good password (plain)" {
  run docker exec mail /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-plain.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking smtp: added user authentication fails with wrong password (plain)" {
  run docker exec mail /bin/sh -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-plain-wrong.txt | grep 'authentication failed'"
  assert_success
}

@test "checking smtp: added user authentication works with good password (login)" {
  run docker exec mail /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-login.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking smtp: added user authentication fails with wrong password (login)" {
  run docker exec mail /bin/sh -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-login-wrong.txt | grep 'authentication failed'"
  assert_success
}

@test "checking smtp: delivers mail to existing account" {
  run docker exec mail /bin/sh -c "grep 'postfix/lmtp' /var/log/mail/mail.log | grep 'status=sent' | grep ' Saved)' | wc -l"
  assert_success
  assert_output 12
}

@test "checking smtp: delivers mail to existing alias" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<alias1@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing alias with recipient delimiter" {
  run docker exec mail /bin/sh -c "grep 'to=<user1~test@localhost.localdomain>, orig_to=<alias1~test@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1

  run docker exec mail /bin/sh -c "grep 'to=<user1~test@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=bounced'"
  assert_failure
}

@test "checking smtp: delivers mail to existing catchall" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<wildcard@localdomain2.com>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to regexp alias" {
  run docker exec mail /bin/sh -c "grep 'to=<user1@localhost.localdomain>, orig_to=<test123@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: user1 should have received 9 mails" {
  run docker exec mail /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l"
  assert_success
  assert_output 9
}

@test "checking smtp: rejects mail to unknown user" {
  run docker exec mail /bin/sh -c "grep '<nouser@localhost.localdomain>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: redirects mail to external aliases" {
  run docker exec mail /bin/sh -c "grep -- '-> <external1@otherdomain.tld>' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 2
}

@test "checking smtp: rejects spam" {
  run docker exec mail /bin/sh -c "grep 'Blocked SPAM' /var/log/mail/mail.log | grep external.tld=spam@my-domain.com | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: rejects virus" {
  run docker exec mail /bin/sh -c "grep 'Blocked INFECTED' /var/log/mail/mail.log | grep external.tld=virus@my-domain.com | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: not advertising smtputf8" {
  # Dovecot does not support SMTPUTF8, so while we can send we cannot receive
  # Better disable SMTPUTF8 support entirely if we can't handle it correctly
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/smtp-ehlo.txt | grep SMTPUTF8 | wc -l"
  assert_success
  assert_output 0
}

#
# accounts
#

@test "checking accounts: user accounts" {
  run docker exec mail doveadm user '*'
  assert_success
  [ "${lines[0]}" = "user1@localhost.localdomain" ]
  [ "${lines[1]}" = "user2@otherdomain.tld" ]
  [ "${lines[2]}" = "added@localhost.localdomain" ]
}

@test "checking accounts: user mail folder for user1" {
  run docker exec mail /bin/bash -c "ls -d /var/mail/localhost.localdomain/user1"
  assert_success
}

@test "checking accounts: user mail folder for user2" {
  run docker exec mail /bin/bash -c "ls -d /var/mail/otherdomain.tld/user2"
  assert_success
}

@test "checking accounts: user mail folder for added user" {
  run docker exec mail /bin/bash -c "ls -d /var/mail/localhost.localdomain/added"
  assert_success
}

@test "checking accounts: comments are not parsed" {
  run docker exec mail /bin/bash -c "ls /var/mail | grep 'comment'"
  assert_failure
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

@test "checking postfix: master.cf overrides" {
  run docker exec mail grep -q 'submission/inet/smtpd_sasl_security_options=noanonymous' /tmp/docker-mailserver/postfix-master.cf
  assert_success
}

#
# dovecot
#

@test "checking dovecot: config additions" {
  run docker exec mail grep -q 'mail_max_userip_connections = 69' /tmp/docker-mailserver/dovecot.cf
  assert_success
  run docker exec mail /bin/sh -c "doveconf | grep 'mail_max_userip_connections = 69'"
  assert_success
  assert_output 'mail_max_userip_connections = 69'
}

#
# spamassassin
#

@test "checking spamassassin: should be listed in amavis when enabled" {
  run docker exec mail /bin/sh -c "grep -i 'ANTI-SPAM-SA code' /var/log/mail/mail.log | grep 'NOT loaded'"
  assert_failure
}

@test "checking spamassassin: should not be listed in amavis when disabled" {
  run docker exec mail_disabled_clamav_spamassassin /bin/sh -c "grep -i 'ANTI-SPAM-SA code' /var/log/mail/mail.log | grep 'NOT loaded'"
  assert_success
}

@test "checking spamassassin: all registered domains should see spam headers" {
  run docker exec mail /bin/sh -c "grep -ir 'X-Spam-' /var/mail/localhost.localdomain/user1/new"
  assert_success
  run docker exec mail /bin/sh -c "grep -ir 'X-Spam-' /var/mail/otherdomain.tld/user2/new"
  assert_success
}


#
# clamav
#

@test "checking clamav: should be listed in amavis when enabled" {
  run docker exec mail grep -i 'Found secondary av scanner ClamAV-clamscan' /var/log/mail/mail.log
  assert_success
}

@test "checking clamav: should not be listed in amavis when disabled" {
  run docker exec mail_disabled_clamav_spamassassin grep -i 'Found secondary av scanner ClamAV-clamscan' /var/log/mail/mail.log
  assert_failure
}

@test "checking clamav: should not be called when disabled" {
  run docker exec mail_disabled_clamav_spamassassin grep -i 'connect to /var/run/clamav/clamd.ctl failed' /var/log/mail/mail.log
  assert_failure
}

#
# opendkim
#

@test "checking opendkim: /etc/opendkim/KeyTable should contain 2 entries" {
  run docker exec mail /bin/sh -c "cat /etc/opendkim/KeyTable | wc -l"
  assert_success
  assert_output 2
}

@test "checking opendkim: /etc/opendkim/KeyTable dummy file generated without keys provided" {
  run docker exec mail_smtponly_without_config /bin/bash -c "cat /etc/opendkim/KeyTable"
  assert_success
}


@test "checking opendkim: /etc/opendkim/keys/ should contain 2 entries" {
  run docker exec mail /bin/sh -c "ls -l /etc/opendkim/keys/ | grep '^d' | wc -l"
  assert_success
  assert_output 2
}

@test "checking opendkim: /etc/opendkim.conf contains nameservers copied from /etc/resolv.conf" {
  run docker exec mail /bin/bash -c "grep -E '^Nameservers ((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' /etc/opendkim.conf"
  assert_success
}


# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar
# Instead it tests the file-size (here 511) - which may differ with a different domain names
# This test may be re-used as a global test to provide better test coverage.
@test "checking opendkim: generator creates default keys size" {
    # Prepare default key size 2048
    rm -rf "$(pwd)/test/config/keyDefault" && mkdir -p "$(pwd)/test/config/keyDefault"
    run docker run --rm \
      -v "$(pwd)/test/config/keyDefault/":/tmp/docker-mailserver/ \
      -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
      -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
      `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
    assert_success
    assert_output 6

  run docker run --rm \
    -v "$(pwd)/test/config/keyDefault/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` \
    /bin/sh -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 511
}

# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar
# Instead it tests the file-size (here 511) - which may differ with a different domain names
# This test may be re-used as a global test to provide better test coverage.
@test "checking opendkim: generator creates key size 2048" {
    # Prepare set key size 2048
    rm -rf "$(pwd)/test/config/key2048" && mkdir -p "$(pwd)/test/config/key2048"
    run docker run --rm \
      -v "$(pwd)/test/config/key2048/":/tmp/docker-mailserver/ \
      -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
      -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
      `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config 2048 | wc -l'
    assert_success
    assert_output 6

  run docker run --rm \
    -v "$(pwd)/test/config/key2048/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` \
    /bin/sh -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 511
}

# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar
# Instead it tests the file-size (here 329) - which may differ with a different domain names
# This test may be re-used as a global test to provide better test coverage.
@test "checking opendkim: generator creates key size 1024" {
    # Prepare set key size 1024
    rm -rf "$(pwd)/test/config/key1024" && mkdir -p "$(pwd)/test/config/key1024"
    run docker run --rm \
      -v "$(pwd)/test/config/key1024/":/tmp/docker-mailserver/ \
      -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
      -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
      `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config 1024 | wc -l'
    assert_success
    assert_output 6

  run docker run --rm \
    -v "$(pwd)/test/config/key1024/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` \
    /bin/sh -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 329
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts" {
  rm -rf "$(pwd)/test/config/empty" && mkdir -p "$(pwd)/test/config/empty"
  run docker run --rm \
    -v "$(pwd)/test/config/empty/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  assert_success
  assert_output 6
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_success
  assert_output 2
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  assert_success
  assert_output 2
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_success
  assert_output 4
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts without postfix-accounts.cf" {
  rm -rf "$(pwd)/test/config/without-accounts" && mkdir -p "$(pwd)/test/config/without-accounts"
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  assert_success
  assert_output 5
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_success
  assert_output 2
  # Check keys for otherdomain.tld
  # run docker run --rm \
  #   -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
  #   `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  # assert_success
  # [ "$output" -eq 0 ]
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_success
  assert_output 4
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts without postfix-virtual.cf" {
  rm -rf "$(pwd)/test/config/without-virtual" && mkdir -p "$(pwd)/test/config/without-virtual"
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  assert_success
  assert_output 5
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_success
  assert_output 2
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  assert_success
  assert_output 2
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_success
  assert_output 4
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts using domain name" {
  rm -rf "$(pwd)/test/config/with-domain" && mkdir -p "$(pwd)/test/config/with-domain"
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-config | wc -l'
  assert_success
  assert_output 6
  # Generate key using domain name
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'generate-dkim-domain testdomain.tld | wc -l'
  assert_success
  assert_output 1
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_success
  assert_output 2
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  assert_success
  assert_output 2
  # Check keys for testdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'ls -1 /etc/opendkim/keys/testdomain.tld | wc -l'
  assert_success
  assert_output 2
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys' | wc -l"
  assert_success
  assert_output 4
  # Check valid entries actually present in KeyTable
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c \
    "egrep 'localhost.localdomain|otherdomain.tld|localdomain2.com|testdomain.tld' /etc/opendkim/KeyTable | wc -l"
  assert_success
  assert_output 4
  # Check valid entries actually present in SigningTable
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c \
    "egrep 'localhost.localdomain|otherdomain.tld|localdomain2.com|testdomain.tld' /etc/opendkim/SigningTable | wc -l"
  assert_success
  assert_output 4
}

#
# ssl
#

@test "checking ssl: generated default cert works correctly" {
  run docker exec mail /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 0 (ok)'"
  assert_success
}

@test "checking ssl: lets-encrypt-x3-cross-signed.pem is installed" {
  run docker exec mail grep 'BEGIN CERTIFICATE' /etc/ssl/certs/lets-encrypt-x3-cross-signed.pem
  assert_success
}

#
# postsrsd
#

@test "checking SRS: main.cf entries" {
  run docker exec mail grep "sender_canonical_maps = tcp:localhost:10001" /etc/postfix/main.cf
  assert_success
  run docker exec mail grep "sender_canonical_classes = envelope_sender" /etc/postfix/main.cf
  assert_success
  run docker exec mail grep "recipient_canonical_maps = tcp:localhost:10002" /etc/postfix/main.cf
  assert_success
  run docker exec mail grep "recipient_canonical_classes = envelope_recipient,header_recipient" /etc/postfix/main.cf
  assert_success
}

@test "checking SRS: postsrsd running" {
  run docker exec mail /bin/sh -c "ps aux | grep ^postsrsd"
  assert_success
}

@test "checking SRS: SRS_DOMAINNAME is used correctly" {
  run docker exec mail_srs_domainname grep "SRS_DOMAIN=srs.my-domain.com" /etc/default/postsrsd
  assert_success
}

@test "checking SRS: OVERRIDE_HOSTNAME is handled correctly" {
  run docker exec mail_override_hostname grep "SRS_DOMAIN=my-domain.com" /etc/default/postsrsd
  assert_success
}

@test "checking SRS: DOMAINNAME is handled correctly" {
  run docker exec mail_domainname grep "SRS_DOMAIN=my-domain.com" /etc/default/postsrsd
  assert_success
}
@test "checking SRS: fallback to hostname is handled correctly" {
  run docker exec mail grep "SRS_DOMAIN=my-domain.com" /etc/default/postsrsd
  assert_success
}

#
# system
#

@test "checking system: freshclam cron is enabled" {
  run docker exec mail bash -c "grep '/usr/bin/freshclam' -r /etc/cron.d"
  assert_success
}

@test "checking amavis: virusmail wiper cron exists" {
  run docker exec mail bash -c "crontab -l | grep '/usr/local/bin/virus-wiper'"
  assert_success
}

@test "checking amavis: VIRUSMAILS_DELETE_DELAY override works as expected" {
  run docker run -ti --rm -e VIRUSMAILS_DELETE_DELAY=2 `docker inspect --format '{{ .Config.Image }}' mail` /bin/bash -c 'echo $VIRUSMAILS_DELETE_DELAY | grep 2'
  assert_success
}

@test "checking amavis: old virusmail is wipped by cron" {
  docker exec mail bash -c 'touch -d "`date --date=2000-01-01`" /var/lib/amavis/virusmails/should-be-deleted'
  run docker exec -ti mail bash -c '/usr/local/bin/virus-wiper'
  assert_success
  run docker exec mail bash -c 'ls -la /var/lib/amavis/virusmails/ | grep should-be-deleted'
  assert_failure
}

@test "checking amavis: recent virusmail is not wipped by cron" {
  docker exec mail bash -c 'touch -d "`date`"  /var/lib/amavis/virusmails/should-not-be-deleted'
  run docker exec -ti mail bash -c '/usr/local/bin/virus-wiper'
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
  run docker exec mail grep -i 'backwards-compatible default setting chroot=y' /var/log/mail/mail.log
  assert_failure
  run docker exec mail grep -i 'connect to 127.0.0.1:10023: Connection refused' /var/log/mail/mail.log
  assert_failure
}

@test "checking system: /var/log/auth.log is error free" {
  run docker exec mail grep 'Unable to open env file: /etc/default/locale' /var/log/auth.log
  assert_failure
}

@test "checking system: sets the server fqdn" {
  run docker exec mail hostname
  assert_success
  assert_output "mail.my-domain.com"
}

@test "checking system: sets the server domain name in /etc/mailname" {
  run docker exec mail cat /etc/mailname
  assert_success
  assert_output "my-domain.com"
}

@test "checking system: postfix should not log to syslog" {
  run docker exec mail grep 'postfix' /var/log/syslog
  assert_failure
}

@test "checking system: amavis decoders installed and available" {
  run docker exec mail /bin/sh -c "grep -E '.*(Internal decoder|Found decoder) for\s+\.(mail|Z|gz|bz2|xz|lzma|lrz|lzo|lz4|rpm|cpio|tar|deb|rar|arj|arc|zoo|doc|cab|tnef|zip|kmz|7z|jar|swf|lha|iso|exe).*' /var/log/mail/mail.log|wc -l"
  assert_success
  assert_output 28
}


#
# sieve
#

@test "checking sieve: user1 should have received 1 email in folder INBOX.spam" {
  run docker exec mail /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/.INBOX.spam/new | wc -l"
  assert_success
  assert_output 1
}

@test "checking manage sieve: server is ready when ENABLE_MANAGESIEVE has been set" {
  run docker exec mail /bin/bash -c "nc -z 0.0.0.0 4190"
  assert_success
}

@test "checking sieve: user2 should have piped 1 email to /tmp/" {
  run docker exec mail /bin/sh -c "ls -A /tmp/pipe-test.out | wc -l"
  assert_success
  assert_output 1
}

@test "checking sieve global: user1 should have gotten a copy of his spam mail" {
  run docker exec mail /bin/sh -c "grep 'Spambot <spam@spam.com>' -R /var/mail/localhost.localdomain/user1/new/"
  assert_success
}

#
# accounts
#
@test "checking accounts: user_without_domain creation should be rejected since user@domain format is required" {
  run docker exec mail /bin/sh -c "addmailuser user_without_domain mypassword"
  assert_failure
  assert_output --partial "username must include the domain"
}

@test "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser user3@domain.tld mypassword"

  run docker exec mail /bin/sh -c "grep '^user3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [ ! -z "$output" ]
}

@test "checking accounts: auser3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser auser3@domain.tld mypassword"

  run docker exec mail /bin/sh -c "grep '^auser3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [ ! -z "$output" ]
}

@test "checking accounts: a.ser3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser a.ser3@domain.tld mypassword"

  run docker exec mail /bin/sh -c "grep '^a\.ser3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [ ! -z "$output" ]
}

@test "checking accounts: user3 should have been removed from /tmp/docker-mailserver/postfix-accounts.cf but not auser3" {
  docker exec mail /bin/sh -c "delmailuser -y user3@domain.tld"

  run docker exec mail /bin/sh -c "grep '^user3@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_failure
  [ -z "$output" ]

  run docker exec mail /bin/sh -c "grep '^auser3@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [ ! -z "$output" ]
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

  docker exec mail /bin/sh -c "delmailuser -y auser3@domain.tld"

  assert_success
}

@test "checking accounts: listmailuser" {
  run docker exec mail /bin/sh -c "listmailuser | head -n 1"
  assert_success
  assert_output 'user1@localhost.localdomain'
}

@test "checking accounts: no error is generated when deleting a user if /tmp/docker-mailserver/postfix-accounts.cf is missing" {
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'delmailuser -y user3@domain.tld'
  assert_success
  [ -z "$output" ]
}

@test "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf even when that file does not exist" {
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c 'addmailuser user3@domain.tld mypassword'
  assert_success
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

@test "checking PERMIT_DOCKER: my network value" {
  run docker exec mail /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.0\.0/16'"
  assert_success
}

#
# amavis
#

@test "checking amavis: config overrides" {
  run docker exec mail /bin/sh -c "grep 'Test Verification' /etc/amavis/conf.d/50-user | wc -l"
  assert_success
  assert_output 1
}


@test "checking user login: predefined user can login" {
  run docker exec mail /bin/bash -c "doveadm auth test -x service=smtp pass@localhost.localdomain 'may be \\a \`p^a.*ssword' | grep 'passdb'"
  assert_output "passdb: pass@localhost.localdomain auth succeeded"
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
@test "checking setup.sh: setup.sh email add and login" {
  wait_for_service mail changedetector
  assert_success

  originalChangesProcessed=$(count_processed_changes mail)

  run ./setup.sh -c mail email add setup_email_add@example.com test_password
  assert_success

  value=$(cat ./test/config/postfix-accounts.cf | grep setup_email_add@example.com | awk -F '|' '{print $1}')
  [ "$value" = "setup_email_add@example.com" ]
  assert_success

  # wait until change detector has processed the change
  count=0
  while [ "${originalChangesProcessed}" = "$(count_processed_changes mail)" ]
  do
    ((count++)) && ((count==60)) && break
    sleep 1
  done

  [ "${originalChangesProcessed}" != "$(count_processed_changes mail)" ]
  assert_success

  # Dovecot has been restarted, but this test often fails so presumably it may not be ready
  # Add a short sleep to see if that helps to make the test more stable
  # Alternatively we could login with a known good user to make sure that the service is up
  sleep 2

  run docker exec mail /bin/bash -c "doveadm auth test -x service=smtp setup_email_add@example.com 'test_password' | grep 'passdb'"
  assert_output "passdb: setup_email_add@example.com auth succeeded"
}

@test "checking setup.sh: setup.sh email list" {
  run ./setup.sh -c mail email list
  assert_success
}

@test "checking setup.sh: setup.sh email update" {
  run ./setup.sh -c mail email add lorem@impsum.org test_test
  assert_success

  initialpass=$(cat ./test/config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $2}')
  [ "$initialpass" != "" ]
  assert_success

  run ./setup.sh -c mail email update lorem@impsum.org my password
  assert_success

  updatepass=$(cat ./test/config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $2}')
  [ "$updatepass" != "" ]
  assert_success

  [ "$initialpass" != "$updatepass" ]
  assert_success

  docker exec mail doveadm pw -t "$updatepass" -p 'my password' | grep 'verified'
  assert_success
}

@test "checking setup.sh: setup.sh email del" {
  run ./setup.sh -c mail email del -y lorem@impsum.org
  assert_success
#
#  TODO delmailuser does not work as expected.
#  Its implementation is not functional, you cannot delete a user data
#  directory in the running container by running a new docker container
#  and not mounting the mail folders (persistance is broken).
#  The add script is only adding the user to account file.
#
#  run docker exec mail ls /var/mail/impsum.org/lorem
#  assert_failure
  run grep lorem@impsum.org ./test/config/postfix-accounts.cf
  assert_failure
}

@test "checking setup.sh: setup.sh email restrict" {
  run ./setup.sh -c mail email restrict
  assert_failure
  run ./setup.sh -c mail email restrict add
  assert_failure
  ./setup.sh -c mail email restrict add send lorem@impsum.org
  run ./setup.sh -c mail email restrict list send
  assert_output --regexp "^lorem@impsum.org.*REJECT"

  run ./setup.sh -c mail email restrict del send lorem@impsum.org
  assert_success
  run ./setup.sh -c mail email restrict list send
  assert_output --partial "Everyone is allowed"

  ./setup.sh -c mail email restrict add receive rec_lorem@impsum.org
  run ./setup.sh -c mail email restrict list receive
  assert_output --regexp "^rec_lorem@impsum.org.*REJECT"
  run ./setup.sh -c mail email restrict del receive rec_lorem@impsum.org
  assert_success
}

# alias
@test "checking setup.sh: setup.sh alias list" {
  mkdir -p ./test/alias/config && echo "test@example.org test@forward.com" > ./test/alias/config/postfix-virtual.cf
  run ./setup.sh -p ./test/alias/config alias list
  assert_success
}
@test "checking setup.sh: setup.sh alias add" {
  mkdir -p ./test/alias/config && echo "" > ./test/alias/config/postfix-virtual.cf
  ./setup.sh -p ./test/alias/config alias add alias@example.com target1@forward.com
  ./setup.sh -p ./test/alias/config alias add alias@example.com target2@forward.com
  sleep 5
  run /bin/sh -c 'cat ./test/alias/config/postfix-virtual.cf | grep "alias@example.com target1@forward.com,target2@forward.com" | wc -l | grep 1'
  assert_success
}
@test "checking setup.sh: setup.sh alias del" {
  # start with a1 -> t1,t2 and a2 -> t1
  mkdir -p ./test/alias/config && echo -e 'alias1@example.org target1@forward.com,target2@forward.com\nalias2@example.org target1@forward.com' > ./test/alias/config/postfix-virtual.cf

  # we remove a1 -> t1 ==> a1 -> t2 and a2 -> t1
  ./setup.sh -p ./test/alias/config alias del alias1@example.org target1@forward.com
  run grep "target1@forward.com" ./test/alias/config/postfix-virtual.cf
  assert_output  --regexp "^alias2@example.org +target1@forward.com$"

  run grep "target2@forward.com" ./test/alias/config/postfix-virtual.cf
  assert_output  --regexp "^alias1@example.org +target2@forward.com$"

  # we remove a1 -> t2 ==> a2 -> t1
  ./setup.sh -p ./test/alias/config alias del alias1@example.org target2@forward.com
  run grep "alias1@example.org" ./test/alias/config/postfix-virtual.cf
  assert_failure

  run grep "alias2@example.org" ./test/alias/config/postfix-virtual.cf
  assert_success

  # we remove a2 -> t1 ==> empty
  ./setup.sh -p ./test/alias/config alias del alias2@example.org target1@forward.com
  run grep "alias2@example.org" ./test/alias/config/postfix-virtual.cf
  assert_failure
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
  [ "$status" -eq 11 ]
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

@test "checking setup.sh: setup.sh relay add-domain" {
  mkdir -p ./test/relay/config && echo -n > ./test/relay/config/postfix-relaymap.cf
  ./setup.sh -p ./test/relay/config relay add-domain example1.org smtp.relay1.com 2525
  ./setup.sh -p ./test/relay/config relay add-domain example2.org smtp.relay2.com
  ./setup.sh -p ./test/relay/config relay add-domain example3.org smtp.relay3.com 2525
  ./setup.sh -p ./test/relay/config relay add-domain example3.org smtp.relay.com 587

  # check adding
  run /bin/sh -c 'cat ./test/relay/config/postfix-relaymap.cf | grep -e "^@example1.org\s\+\[smtp.relay1.com\]:2525" | wc -l | grep 1'
  assert_success
  # test default port
  run /bin/sh -c 'cat ./test/relay/config/postfix-relaymap.cf | grep -e "^@example2.org\s\+\[smtp.relay2.com\]:25" | wc -l | grep 1'
  assert_success
  # test modifying
  run /bin/sh -c 'cat ./test/relay/config/postfix-relaymap.cf | grep -e "^@example3.org\s\+\[smtp.relay.com\]:587" | wc -l | grep 1'
  assert_success
}

@test "checking setup.sh: setup.sh relay add-auth" {
  mkdir -p ./test/relay/config && echo -n > ./test/relay/config/postfix-sasl-password.cf
  ./setup.sh -p ./test/relay/config relay add-auth example.org smtp_user smtp_pass
  ./setup.sh -p ./test/relay/config relay add-auth example2.org smtp_user2 smtp_pass2
  ./setup.sh -p ./test/relay/config relay add-auth example2.org smtp_user2 smtp_pass_new

  # test adding
  run /bin/sh -c 'cat ./test/relay/config/postfix-sasl-password.cf | grep -e "^@example.org\s\+smtp_user:smtp_pass" | wc -l | grep 1'
  assert_success
  # test updating
  run /bin/sh -c 'cat ./test/relay/config/postfix-sasl-password.cf | grep -e "^@example2.org\s\+smtp_user2:smtp_pass_new" | wc -l | grep 1'
  assert_success
}

@test "checking setup.sh: setup.sh relay exclude-domain" {
  mkdir -p ./test/relay/config && echo -n > ./test/relay/config/postfix-relaymap.cf
  ./setup.sh -p ./test/relay/config relay exclude-domain example.org

  run /bin/sh -c 'cat ./test/relay/config/postfix-relaymap.cf | grep -e "^@example.org\s*$" | wc -l | grep 1'
  assert_success
}

#
# LDAP
#

# postfix

@test "checking dovecot: postmaster address" {
  run docker exec mail /bin/sh -c "grep 'postmaster_address = postmaster@my-domain.com' /etc/dovecot/conf.d/15-lda.conf"
  assert_success

  run docker exec mail_override_hostname /bin/sh -c "grep 'postmaster_address = postmaster@my-domain.com' /etc/dovecot/conf.d/15-lda.conf"
  assert_success
}

@test "checking spoofing: rejects sender forging" {
  # checking rejection of spoofed sender
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-spoofed.txt | grep 'Sender address rejected: not owned by user'"
  assert_success
}

@test "checking spoofing: accepts sending as alias" {

  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-spoofed-alias.txt | grep 'End data with'"
  assert_success
}

#
# Pflogsumm delivery check
#

@test "checking pflogsum delivery" {
  # checking logrotation working and report being sent
  docker exec mail logrotate --force /etc/logrotate.d/maillog
  sleep 10
  run docker exec mail grep "Subject: Postfix Summary for " /var/mail/localhost.localdomain/user1/new/ -R
  assert_success
  # check sender is the one specified in REPORT_SENDER
  run docker exec mail grep "From: report1@mail.my-domain.com" /var/mail/localhost.localdomain/user1/new/ -R
  assert_success
  # check sender is not the default one.
  run docker exec mail grep "From: mailserver-report@mail.my-domain.com" /var/mail/localhost.localdomain/user1/new/ -R
  assert_failure
}


#
# PCI compliance
#

# dovecot
@test "checking dovecot: only A grade TLS ciphers are used" {
  run docker run --rm -i --link mail:dovecot \
    --entrypoint sh instrumentisto/nmap -c \
      'nmap --script ssl-enum-ciphers -p 993 dovecot | grep "least strength: A"'
  assert_success
}

@test "checking dovecot: nmap produces no warnings on TLS ciphers verifying" {
  run docker run --rm -i --link mail:dovecot \
    --entrypoint sh instrumentisto/nmap -c \
      'nmap --script ssl-enum-ciphers -p 993 dovecot | grep "warnings" | wc -l'
  assert_success
  assert_output 0
}

# postfix submission TLS
@test "checking postfix submission: only A grade TLS ciphers are used" {
  run docker run --rm -i --link mail:postfix \
    --entrypoint sh instrumentisto/nmap -c \
      'nmap --script ssl-enum-ciphers -p 587 postfix | grep "least strength: A"'
  assert_success
}

@test "checking postfix submission: nmap produces no warnings on TLS ciphers verifying" {
  run docker run --rm -i --link mail:postfix \
    --entrypoint sh instrumentisto/nmap -c \
      'nmap --script ssl-enum-ciphers -p 587 postfix | grep "warnings" | wc -l'
  assert_success
  assert_output 0
}

# postfix smtps SSL
@test "checking postfix smtps: only A grade TLS ciphers are used" {
  run docker run --rm -i --link mail:postfix \
    --entrypoint sh instrumentisto/nmap -c \
      'nmap --script ssl-enum-ciphers -p 465 postfix | grep "least strength: A"'
  assert_success
}

@test "checking postfix smtps: nmap produces no warnings on TLS ciphers verifying" {
  run docker run --rm -i --link mail:postfix \
    --entrypoint sh instrumentisto/nmap -c \
      'nmap --script ssl-enum-ciphers -p 465 postfix | grep "warnings" | wc -l'
  assert_success
  assert_output 0
}


#
# supervisor
#

@test "checking restart of process: postfix" {
  run docker exec mail /bin/bash -c "pkill master && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/lib/postfix/sbin/master'"
  assert_success
}

@test "checking restart of process: clamd" {
  run docker exec mail /bin/bash -c "pkill clamd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_success
}

@test "checking restart of process: amavisd-new" {
  run docker exec mail /bin/bash -c "pkill amavi && sleep 12 && ps aux --forest | grep -v grep | grep '/usr/sbin/amavisd-new (master)'"
  assert_success
}

@test "checking restart of process: opendkim" {
  run docker exec mail /bin/bash -c "pkill opendkim && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/opendkim'"
  assert_success
}

@test "checking restart of process: opendmarc" {
  run docker exec mail /bin/bash -c "pkill opendmarc && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/opendmarc'"
  assert_success
}

@test "checking restart of process: clamav (clamav disabled by ENABLED_CLAMAV=0)" {
  run docker exec mail_disabled_clamav_spamassassin /bin/bash -c "pkill -f clamd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_failure
}

#
# root mail delivery
#

@test "checking that mail for root was delivered" {
  run docker exec mail grep "Subject: Root Test Message" /var/mail/localhost.localdomain/user1/new/ -R
  assert_success
}

#
# clean exit
#

@test "checking that the container stops cleanly" {
  run docker stop -t 60 mail
  assert_success
}
