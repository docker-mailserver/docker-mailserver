load 'test_helper/common'

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_with_postgrey \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_DNSBL=1 \
    -e ENABLE_POSTGREY=1 \
    -e PERMIT_DOCKER=container \
    -e POSTGREY_AUTO_WHITELIST_CLIENTS=5 \
    -e POSTGREY_DELAY=15 \
    -e POSTGREY_MAX_AGE=35 \
    -e POSTGREY_TEXT="Delayed by Postgrey" \
    -h mail.my-domain.com -t "${NAME}"

  # using postfix availability as start indicator, this might be insufficient for postgrey
  wait_for_smtp_port_in_container mail_with_postgrey
}

function teardown_file() {
  docker rm -f mail_with_postgrey
}

@test "checking postgrey: /etc/postfix/main.cf correctly edited" {
  run docker exec mail_with_postgrey /bin/bash -c "grep 'zen.spamhaus.org, check_policy_service inet:127.0.0.1:10023' /etc/postfix/main.cf | wc -l"
  assert_success
  assert_output 1
}

@test "checking postgrey: /etc/default/postgrey correctly edited and has the default values" {
  run docker exec mail_with_postgrey /bin/bash -c "grep '^POSTGREY_OPTS=\"--inet=127.0.0.1:10023 --delay=15 --max-age=35 --auto-whitelist-clients=5\"$' /etc/default/postgrey | wc -l"
  assert_success
  assert_output 1

  run docker exec mail_with_postgrey /bin/bash -c "grep '^POSTGREY_TEXT=\"Delayed by Postgrey\"$' /etc/default/postgrey | wc -l"
  assert_success
  assert_output 1
}

@test "checking process: postgrey (postgrey server enabled)" {
  run docker exec mail_with_postgrey /bin/bash -c "ps aux --forest | grep -v grep | grep 'postgrey'"
  assert_success
}

@test "checking postgrey: there should be a log entry about a new greylisted e-mail user@external.tld in /var/log/mail/mail.log" {
  #editing the postfix config in order to ensure that postgrey handles the test e-mail. The other spam checks at smtpd_recipient_restrictions would interfere with it.
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

@test "checking postgrey: there should be a log entry about the whitelisted local and passed e-mail user@whitelistlocal.tld in /var/log/mail/mail.log" {
  run docker exec mail_with_postgrey /bin/sh -c "nc -w 8 0.0.0.0 10023 < /tmp/docker-mailserver-test/nc_templates/postgrey_whitelist_local.txt"
  run docker exec mail_with_postgrey /bin/sh -c "grep -i 'action=pass, reason=client whitelist' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking postgrey: there should be a log entry about the whitelisted recipient user2@otherdomain.tld in /var/log/mail/mail.log" {
  run docker exec mail_with_postgrey /bin/sh -c "nc -w 8 0.0.0.0 10023 < /tmp/docker-mailserver-test/nc_templates/postgrey_whitelist_recipients.txt"
  run docker exec mail_with_postgrey /bin/sh -c "grep -i 'action=pass, reason=recipient whitelist' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}
