load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
#
# configuration checks
#

@test "checking configuration: hostname/domainname" {
  run docker run `docker inspect --format '{{ .Config.Image }}' mail`
  assert_failure
}

@test "checking configuration: hostname/domainname override" {
  run docker exec mail_smtponly /bin/bash -c "cat /etc/mailname | grep my-domain.com"
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

@test "checking process: fail2ban (fail2ban server enabled)" {
  run docker exec mail_fail2ban /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/python3 /usr/bin/fail2ban-server'"
  assert_success
}

@test "checking process: fetchmail (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  assert_failure
}

@test "checking process: fetchmail (fetchmail server enabled)" {
  run docker exec mail_fetchmail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  assert_success
}

@test "checking process: clamav (clamav disabled by ENABLED_CLAMAV=0)" {
  run docker exec mail_disabled_clamav_spamassassin /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_failure
}

@test "checking process: saslauthd (saslauthd server enabled)" {
  run docker exec mail_with_ldap /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
  assert_success
}


#
# postgrey
#

@test "checking process: postgrey (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep 'postgrey'"
  assert_failure
}

@test "checking postgrey: /etc/postfix/main.cf correctly edited" {
  run docker exec mail_with_postgrey /bin/bash -c "grep 'bl.spamcop.net, check_policy_service inet:127.0.0.1:10023' /etc/postfix/main.cf | wc -l"
  assert_success
  assert_output 1
}

@test "checking postgrey: /etc/default/postgrey correctly edited and has the default values" {
  run docker exec mail_with_postgrey /bin/bash -c "grep '^POSTGREY_OPTS=\"--inet=127.0.0.1:10023 --delay=15 --max-age=35\"$' /etc/default/postgrey | wc -l"
  assert_success
  assert_output 1
  run docker exec mail_with_postgrey /bin/bash -c "grep '^POSTGREY_TEXT=\"Delayed by postgrey\"$' /etc/default/postgrey | wc -l"
  assert_success
  assert_output 1
}

@test "checking process: postgrey (postgrey server enabled)" {
  run docker exec mail_with_postgrey /bin/bash -c "ps aux --forest | grep -v grep | grep 'postgrey'"
  assert_success
}

@test "checking postgrey: there should be a log entry about a new greylisted e-mail user@external.tld in /var/log/mail/mail.log" {
  #editing the postfix config in order to ensure that postgrey handles the test e-mail. The other spam checks at smtpd_recipient_restrictionswould interfere with it.
  run docker exec mail_with_postgrey /bin/sh -c "sed -ie 's/permit_sasl_authenticated.*policyd-spf,$//g' /etc/postfix/main.cf"
  run docker exec mail_with_postgrey /bin/sh -c "sed -ie 's/reject_unauth_pipelining.*reject_unknown_recipient_domain,$//g' /etc/postfix/main.cf"
  run docker exec mail_with_postgrey /bin/sh -c "sed -ie 's/reject_rbl_client.*inet:127\.0\.0\.1:10023$//g' /etc/postfix/main.cf"
  run docker exec mail_with_postgrey /bin/sh -c "sed -ie 's/smtpd_recipient_restrictions =/smtpd_recipient_restrictions = check_policy_service inet:127.0.0.1:10023/g' /etc/postfix/main.cf"

  run docker exec mail_with_postgrey /bin/sh -c "/etc/init.d/postfix reload"
  run docker exec mail_with_postgrey /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/postgrey.txt"
  sleep 5 #ensure that the information has been written into the log
  run docker exec mail_with_postgrey /bin/bash -c "grep -i 'action=greylist.*user@external\.tld' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking postgrey: there should be a log entry about the retried and passed e-mail user@external.tld in /var/log/mail/mail.log" {
  sleep 20 #wait 20 seconds so that postgrey would accept the message
  run docker exec mail_with_postgrey /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/postgrey.txt"
  sleep 8
  run docker exec mail_with_postgrey /bin/sh -c "grep -i 'action=pass, reason=triplet found.*user@external\.tld' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking postgrey: there should be a log entry about the whitelisted and passed e-mail user@whitelist.tld in /var/log/mail/mail.log" {
  run docker exec mail_with_postgrey /bin/sh -c "nc -w 8 0.0.0.0 10023 < /tmp/docker-mailserver-test/nc_templates/postgrey_whitelist.txt"
  run docker exec mail_with_postgrey /bin/sh -c "grep -i 'action=pass, reason=client whitelist' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

#
# imap
#

@test "checking process: dovecot imaplogin (enabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  assert_success
}

@test "checking process: dovecot imaplogin (disabled using SMTP_ONLY)" {
  run docker exec mail_smtponly /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  assert_failure
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
# pop
#

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

@test "checking accounts: user mail folders for user1" {
  run docker exec mail /bin/bash -c "ls -A /var/mail/localhost.localdomain/user1 | grep -E '.Drafts|.Sent|.Trash|cur|new|subscriptions|tmp' | wc -l"
  assert_success
  assert_output 7
}

@test "checking accounts: user mail folders for user2" {
  run docker exec mail /bin/bash -c "ls -A /var/mail/otherdomain.tld/user2 | grep -E '.Drafts|.Sent|.Trash|cur|new|subscriptions|tmp' | wc -l"
  assert_success
  assert_output 7
}

@test "checking accounts: user mail folders for added user" {
  run docker exec mail /bin/bash -c "ls -A /var/mail/localhost.localdomain/added | grep -E '.Drafts|.Sent|.Trash|cur|new|subscriptions|tmp' | wc -l"
  assert_success
  assert_output 7
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

@test "checking spamassassin: docker env variables are set correctly (custom)" {
  run docker exec mail /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= -5.0'"
  assert_success
  run docker exec mail /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  assert_success
  run docker exec mail /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 3.0'"
  assert_success
  run docker exec mail /bin/sh -c "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= .SPAM: .'"
  assert_success
  run docker exec mail_undef_spam_subject /bin/sh -c "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= undef'"
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
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
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
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
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
    `docker inspect --format '{{ .Config.Image }}' mail` /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
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

@test "checking ssl: manual configuration is correct" {
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/cert" /etc/postfix/main.cf | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/cert" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/key" /etc/postfix/main.cf | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/key" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
  assert_success
  assert_output 1
}

@test "checking ssl: manual configuration copied files correctly " {
  run docker exec mail_manual_ssl /bin/sh -c 'cmp -s /etc/postfix/ssl/cert /tmp/docker-mailserver/letsencrypt/mail.my-domain.com/fullchain.pem'
  assert_success
  run docker exec mail_manual_ssl /bin/sh -c 'cmp -s /etc/postfix/ssl/key /tmp/docker-mailserver/letsencrypt/mail.my-domain.com/privkey.pem'
  assert_success
}

@test "checking ssl: manual cert works correctly" {
  run docker exec mail_manual_ssl /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
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
# fail2ban
#

@test "checking fail2ban: localhost is not banned because ignored" {
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status postfix-sasl | grep 'IP list:.*127.0.0.1'"
  assert_failure
  run docker exec mail_fail2ban /bin/sh -c "grep 'ignoreip = 127.0.0.1/8' /etc/fail2ban/jail.conf"
  assert_success
}

@test "checking fail2ban: fail2ban-fail2ban.cf overrides" {
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client get loglevel | grep DEBUG"
  assert_success
}

@test "checking fail2ban: fail2ban-jail.cf overrides" {
  FILTERS=(sshd postfix dovecot postfix-sasl)

  for FILTER in "${FILTERS[@]}"; do
    run docker exec mail_fail2ban /bin/sh -c "fail2ban-client get $FILTER bantime"
    assert_output 1234

    run docker exec mail_fail2ban /bin/sh -c "fail2ban-client get $FILTER findtime"
    assert_output 321

    run docker exec mail_fail2ban /bin/sh -c "fail2ban-client get $FILTER maxretry"
    assert_output 2
  done
}

@test "checking fail2ban: ban ip on multiple failed login" {
  # Getting mail_fail2ban container IP
  MAIL_FAIL2BAN_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mail_fail2ban)

  # Create a container which will send wrong authentications and should get banned
  docker run --name fail-auth-mailer -e MAIL_FAIL2BAN_IP=$MAIL_FAIL2BAN_IP -v "$(pwd)/test":/tmp/docker-mailserver-test -d $(docker inspect --format '{{ .Config.Image }}' mail) tail -f /var/log/faillog

  # can't pipe the file as usual due to postscreen. (respecting postscreen_greet_wait time and talking in turn):
  for i in {1,2}; do
    docker exec fail-auth-mailer /bin/bash -c \
    'exec 3<>/dev/tcp/$MAIL_FAIL2BAN_IP/25 && \
    while IFS= read -r cmd; do \
      head -1 <&3; \
      [[ "$cmd" == "EHLO"* ]] && sleep 6; \
      echo $cmd >&3; \
    done < "/tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt"'
  done

  sleep 5

  # Checking that FAIL_AUTH_MAILER_IP is banned in mail_fail2ban
  FAIL_AUTH_MAILER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' fail-auth-mailer)

  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status postfix-sasl | grep '$FAIL_AUTH_MAILER_IP'"
  assert_success

  # Checking that FAIL_AUTH_MAILER_IP is banned by iptables
  run docker exec mail_fail2ban /bin/sh -c "iptables -L f2b-postfix-sasl -n | grep REJECT | grep '$FAIL_AUTH_MAILER_IP'"
  assert_success
}

@test "checking fail2ban: unban ip works" {
  FAIL_AUTH_MAILER_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' fail-auth-mailer)

  docker exec mail_fail2ban fail2ban-client set postfix-sasl unbanip $FAIL_AUTH_MAILER_IP

  sleep 5

  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client status postfix-sasl | grep 'IP list:.*$FAIL_AUTH_MAILER_IP'"
  assert_failure

  # Checking that FAIL_AUTH_MAILER_IP is unbanned by iptables
  run docker exec mail_fail2ban /bin/sh -c "iptables -L f2b-postfix-sasl -n | grep REJECT | grep '$FAIL_AUTH_MAILER_IP'"
  assert_failure
}

#
# postscreen
#

@test "checking postscreen" {
  # Getting mail container IP
  MAIL_POSTSCREEN_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mail_postscreen)

  # talk too fast:

  docker exec fail-auth-mailer /bin/sh -c "nc $MAIL_POSTSCREEN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt"
  sleep 5

  run docker exec mail_postscreen grep 'COMMAND PIPELINING' /var/log/mail/mail.log
  assert_success

  # positive test. (respecting postscreen_greet_wait time and talking in turn):
  for i in {1,2}; do
    docker exec fail-auth-mailer /bin/bash -c \
    'exec 3<>/dev/tcp/'$MAIL_POSTSCREEN_IP'/25 && \
    while IFS= read -r cmd; do \
      head -1 <&3; \
      [[ "$cmd" == "EHLO"* ]] && sleep 6; \
      echo $cmd >&3; \
    done < "/tmp/docker-mailserver-test/auth/smtp-auth-login.txt"'
  done

  sleep 5

  run docker exec mail_postscreen grep 'PASS NEW ' /var/log/mail/mail.log
  assert_success
}

#
# fetchmail
#

@test "checking fetchmail: gerneral options in fetchmailrc are loaded" {
  run docker exec mail_fetchmail grep 'set syslog' /etc/fetchmailrc
  assert_success
}

@test "checking fetchmail: fetchmail.cf is loaded" {
  run docker exec mail_fetchmail grep 'pop3.example.com' /etc/fetchmailrc
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
  run docker exec mail_pop3 grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure
  run docker exec mail_pop3 grep ': error:' /var/log/mail/mail.log
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

@test "checking manage sieve: disabled per default" {
  run docker exec mail_pop3 /bin/bash -c "nc -z 0.0.0.0 4190"
  assert_failure
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

@test "checking PERMIT_DOCKER: opendmarc/opendkim config" {
  run docker exec mail_smtponly /bin/sh -c "cat /etc/opendmarc/ignore.hosts | grep '172.16.0.0/12'"
  assert_success
  run docker exec mail_smtponly /bin/sh -c "cat /etc/opendkim/TrustedHosts | grep '172.16.0.0/12'"
  assert_success
}

@test "checking PERMIT_DOCKER: my network value" {
  run docker exec mail /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.0\.0/16'"
  assert_success
  run docker exec mail_pop3 /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}/32'"
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
  result=$(docker exec mail doveadm auth test -x service=smtp pass@localhost.localdomain 'may be \a `p^a.*ssword' | grep 'auth succeeded')
  [ "$result" = "passdb: pass@localhost.localdomain auth succeeded" ]
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
@test "checking setup.sh: setup.sh email add" {
  run ./setup.sh -c mail email add setup_email_add@example.com test_password
  assert_success

  value=$(cat ./test/config/postfix-accounts.cf | grep setup_email_add@example.com | awk -F '|' '{print $1}')
  [ "$value" = "setup_email_add@example.com" ]

  # we test the login of this user later to let the container digest the addition
}

@test "checking setup.sh: setup.sh email list" {
  run ./setup.sh -c mail email list
  assert_success
}

@test "checking setup.sh: setup.sh email update" {
  ./setup.sh -c mail email add lorem@impsum.org test_test && initialpass=$(cat ./test/config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $2}')
  run ./setup.sh -c mail email update lorem@impsum.org my password
  updatepass=$(cat ./test/config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $2}')
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
@test "checking setup.sh: setup.sh debug fail2ban" {

  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client set dovecot banip 192.0.66.4"
  run docker exec mail_fail2ban /bin/sh -c "fail2ban-client set dovecot banip 192.0.66.5"
  sleep 10
  run ./setup.sh -c mail_fail2ban debug fail2ban
  assert_output --regexp "^Banned in dovecot: 192.0.66.5 192.0.66.4.*"
  run ./setup.sh -c mail_fail2ban debug fail2ban unban 192.0.66.4
  assert_output --partial "unbanned IP from dovecot: 192.0.66.4"
  run ./setup.sh -c mail_fail2ban debug fail2ban
  assert_output --regexp "^Banned in dovecot: 192.0.66.5.*"
  run ./setup.sh -c mail_fail2ban debug fail2ban unban 192.0.66.5
  run ./setup.sh -c mail_fail2ban debug fail2ban unban
  assert_output --partial "You need to specify an IP address. Run"
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

@test "checking setup.sh: email add login validation" {
  # validates that the user created previously with setup.sh can login
  result=$(docker exec mail doveadm auth test -x service=smtp setup_email_add@example.com 'test_password' | grep 'auth succeeded')
  [ "$result" = "passdb: setup_email_add@example.com auth succeeded" ]
}

#
# LDAP
#

# postfix
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

@test "checking postfix: remove privacy details of the sender" {
  run docker exec mail_privacy /bin/sh -c "ls /var/mail/localhost.localdomain/user1/new | wc -l"
  assert_success
  assert_output 1
  run docker exec mail_privacy /bin/sh -c "grep -rE "^User-Agent:" /var/mail/localhost.localdomain/user1/new | wc -l"
  assert_success
  assert_output 0
}

# dovecot
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
  run docker exec mail /bin/sh -c "grep 'postmaster_address = postmaster@my-domain.com' /etc/dovecot/conf.d/15-lda.conf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'postmaster_address = postmaster@localhost.localdomain' /etc/dovecot/conf.d/15-lda.conf"
  assert_success

  run docker exec mail_override_hostname /bin/sh -c "grep 'postmaster_address = postmaster@my-domain.com' /etc/dovecot/conf.d/15-lda.conf"
  assert_success
}

@test "checking spoofing: rejects sender forging" {
  # checking rejection of spoofed sender
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-spoofed.txt | grep 'Sender address rejected: not owned by user'"
  assert_success
  # checking ldap
  run docker exec mail_with_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed.txt | grep 'Sender address rejected: not owned by user'"
  assert_success
}

@test "checking spoofing: accepts sending as alias" {

  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-spoofed-alias.txt | grep 'End data with'"
  assert_success
  # checking ldap alias
  run docker exec mail_with_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed-alias.txt | grep 'End data with'"
  assert_success
}

# saslauthd
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


#
# RIMAP
#

# dovecot
@test "checking dovecot: ldap rimap connection and authentication works" {
  run docker exec mail_with_imap /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-auth.txt"
  assert_success
}

# saslauthd
@test "checking saslauthd: sasl rimap authentication works" {
  run docker exec mail_with_imap bash -c "testsaslauthd -u user1@localhost.localdomain -p mypassword"
  assert_success
}

@test "checking saslauthd: rimap smtp authentication" {
  run docker exec mail_with_imap /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt | grep 'Authentication successful'"
  assert_success
}

#
# Postfix VIRTUAL_TRANSPORT
#
@test "checking postfix-lmtp: virtual_transport config is set" {
  run docker exec mail_lmtp_ip /bin/sh -c "grep 'virtual_transport = lmtp:127.0.0.1:24' /etc/postfix/main.cf"
  assert_success
}

@test "checking postfix-lmtp: delivers mail to existing account" {
  run docker exec mail_lmtp_ip /bin/sh -c "grep 'postfix/lmtp' /var/log/mail/mail.log | grep 'status=sent' | grep ' Saved)' | wc -l"
  assert_success
  assert_output 1
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
  
  # checking default sender is correctly set when env variable not defined
  run docker exec mail_with_ldap grep "mailserver-report@mail.my-domain.com" /etc/logrotate.d/maillog
  assert_success
  # checking default logrotation setup
  run docker exec mail_with_ldap grep "daily" /etc/logrotate.d/maillog
  assert_success
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

@test "checking restart of process: fail2ban (fail2ban server enabled)" {
  run docker exec mail_fail2ban /bin/bash -c "pkill fail2ban && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/bin/python3 /usr/bin/fail2ban-server'"
  assert_success
}

@test "checking restart of process: fetchmail" {
  run docker exec mail_fetchmail /bin/bash -c "pkill fetchmail && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  assert_success
}

@test "checking restart of process: clamav (clamav disabled by ENABLED_CLAMAV=0)" {
  run docker exec mail_disabled_clamav_spamassassin /bin/bash -c "pkill -f clamd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_failure
}

@test "checking restart of process: saslauthd (saslauthd server enabled)" {
  run docker exec mail_with_ldap /bin/bash -c "pkill saslauthd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
  assert_success
}

#
# relay hosts
#

@test "checking relay hosts: default mapping is added from env vars" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domainone.tld\s\+\[default.relay.com\]:2525" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: custom mapping is added from file" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domaintwo.tld\s\+\[other.relay.com\]:587" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: ignored domain is not added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domainthree.tld\s\+\[any.relay.com\]:25" | wc -l | grep 0'
  assert_success
}

@test "checking relay hosts: auth entry is added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/sasl_passwd | grep -e "^@domaintwo.tld\s\+smtp_user_2:smtp_password_2" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: default auth entry is added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/sasl_passwd | grep -e "^\[default.relay.com\]:2525\s\+smtp_user:smtp_password" | wc -l | grep 1'
  assert_success
}

#
# root mail delivery
#

@test "checking that mail for root was delivered" {
  run docker exec mail grep "Subject: Root Test Message" /var/mail/localhost.localdomain/user1/new/ -R
  assert_success
}
