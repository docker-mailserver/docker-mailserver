sublload 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
#
# configuration checks
#


#
# postgrey
#


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
# spamassassin
#

@test "checking spamassassin: docker env variables are set correctly (custom)" {
  run docker exec mail_undef_spam_subject /bin/sh -c "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= undef'"
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
# system
#



@test "checking amavis: VIRUSMAILS_DELETE_DELAY override works as expected" {
  run docker run -ti --rm -e VIRUSMAILS_DELETE_DELAY=2 `docker inspect --format '{{ .Config.Image }}' mail` /bin/bash -c 'echo $VIRUSMAILS_DELETE_DELAY | grep 2'
  assert_success
}








#
# accounts
#

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
  run ./setup.sh email add lorem@impsum.org dolorsit
  assert_success
  value=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $1}')
  [ "$value" = "lorem@impsum.org" ]

}

@test "checking setup.sh: setup.sh email list" {
  run ./setup.sh email list
  assert_success
}

@test "checking setup.sh: setup.sh email update" {
  initialpass=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $2}')
  run ./setup.sh email update lorem@impsum.org consectetur
  updatepass=$(cat ./config/postfix-accounts.cf | grep lorem@impsum.org | awk -F '|' '{print $2}')
  [ "$initialpass" != "$changepass" ]

  assert_success
}

##TODO
@test "checking setup.sh: setup.sh email del" {
  run ./setup.sh email del -y lorem@impsum.org
  assert_success
  run docker exec mail ls /var/mail/impsum.org/lorem
  assert_failure
  run grep lorem@impsum.org ./config/postfix-accounts.cf
  assert_failure
}


# alias
@test "checking setup.sh: setup.sh alias list" {
  echo "test@example.org test@forward.com" > ./config/postfix-virtual.cf
  run ./setup.sh alias list
  assert_success
}
@test "checking setup.sh: setup.sh alias add" {
  echo "" > ./config/postfix-virtual.cf
  ./setup.sh alias add test1@example.org test1@forward.com
  ./setup.sh alias add test1@example.org test2@forward.com

  run /bin/sh -c 'cat ./config/postfix-virtual.cf | grep "test1@example.org test1@forward.com,test2@forward.com" | wc -l | grep 1'
  assert_success
}
@test "checking setup.sh: setup.sh alias del" {
  echo -e 'test1@example.org test1@forward.com,test2@forward.com\ntest2@example.org test1@forward.com' > ./config/postfix-virtual.cf

  ./setup.sh alias del test1@example.org test1@forward.com
  run grep "test1@forward.com" ./config/postfix-virtual.cf
  assert_output  --regexp "^test2@example.org +test1@forward.com$"

  run grep "test2@forward.com" ./config/postfix-virtual.cf
  assert_output  --regexp "^test1@example.org +test2@forward.com$"

  ./setup.sh alias del test1@example.org test2@forward.com
  run grep "test1@example.org" ./config/postfix-virtual.cf
  assert_failure

  run grep "test2@example.org" ./config/postfix-virtual.cf
  assert_success

  ./setup.sh alias del test2@example.org test1@forward.com
  run grep "test2@example.org" ./config/postfix-virtual.cf
  assert_failure
}

# config
@test "checking setup.sh: setup.sh config dkim" {
  run ./setup.sh config dkim
  assert_success
}
# TODO: To create a test generate-ssl-certificate must be non interactive
#@test "checking setup.sh: setup.sh config ssl" {
#  run ./setup.sh config ssl
#  assert_success
#}

# debug
@test "checking setup.sh: setup.sh debug fetchmail" {
  run ./setup.sh debug fetchmail
  [ "$status" -eq 5 ]
# TODO: Fix output check
# [ "$output" = "fetchmail: no mailservers have been specified." ]
}


@test "checking setup.sh: setup.sh relay add-domain" {
  echo -n > ./config/postfix-relaymap.cf
  ./setup.sh relay add-domain example1.org smtp.relay1.com 2525
  ./setup.sh relay add-domain example2.org smtp.relay2.com
  ./setup.sh relay add-domain example3.org smtp.relay3.com 2525
  ./setup.sh relay add-domain example3.org smtp.relay.com 587

  # check adding
  run /bin/sh -c 'cat ./config/postfix-relaymap.cf | grep -e "^@example1.org\s\+\[smtp.relay1.com\]:2525" | wc -l | grep 1'
  assert_success
  # test default port
  run /bin/sh -c 'cat ./config/postfix-relaymap.cf | grep -e "^@example2.org\s\+\[smtp.relay2.com\]:25" | wc -l | grep 1'
  assert_success
  # test modifying
  run /bin/sh -c 'cat ./config/postfix-relaymap.cf | grep -e "^@example3.org\s\+\[smtp.relay.com\]:587" | wc -l | grep 1'
  assert_success
}

@test "checking setup.sh: setup.sh relay add-auth" {
  echo -n > ./config/postfix-sasl-password.cf
  ./setup.sh relay add-auth example.org smtp_user smtp_pass
  ./setup.sh relay add-auth example2.org smtp_user2 smtp_pass2
  ./setup.sh relay add-auth example2.org smtp_user2 smtp_pass_new

  # test adding
  run /bin/sh -c 'cat ./config/postfix-sasl-password.cf | grep -e "^@example.org\s\+smtp_user:smtp_pass" | wc -l | grep 1'
  assert_success
  # test updating
  run /bin/sh -c 'cat ./config/postfix-sasl-password.cf | grep -e "^@example2.org\s\+smtp_user2:smtp_pass_new" | wc -l | grep 1'
  assert_success
}

@test "checking setup.sh: setup.sh relay exclude-domain" {
  echo -n > ./config/postfix-relaymap.cf
  ./setup.sh relay exclude-domain example.org

  run /bin/sh -c 'cat ./config/postfix-relaymap.cf | grep -e "^@example.org\s*$" | wc -l | grep 1'
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
# supervisor
#

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
