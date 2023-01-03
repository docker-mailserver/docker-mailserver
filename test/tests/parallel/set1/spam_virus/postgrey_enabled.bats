load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_NAME_PREFIX='Postgrey (enabled):'
CONTAINER_NAME='dms-test_postgrey_enabled'

function setup_file() {
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_DNSBL=1
    --env ENABLE_POSTGREY=1
    --env PERMIT_DOCKER=container
    --env POSTGREY_AUTO_WHITELIST_CLIENTS=5
    --env POSTGREY_DELAY=15
    --env POSTGREY_MAX_AGE=35
    --env POSTGREY_TEXT="Delayed by Postgrey"
  )

  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Postfix needs to be ready on port 25 for nc usage below:
  wait_for_smtp_port_in_container "${CONTAINER_NAME}"
}

function teardown_file() { _default_teardown ; }

@test "${TEST_NAME_PREFIX} /etc/postfix/main.cf correctly edited" {
  _run_in_container bash -c "grep -F 'zen.spamhaus.org=127.0.0.[2..11], check_policy_service inet:127.0.0.1:10023' /etc/postfix/main.cf | wc -l"
  assert_success
  assert_output 1
}

@test "${TEST_NAME_PREFIX} /etc/default/postgrey correctly edited and has the default values" {
  _run_in_container bash -c "grep '^POSTGREY_OPTS=\"--inet=127.0.0.1:10023 --delay=15 --max-age=35 --auto-whitelist-clients=5\"$' /etc/default/postgrey | wc -l"
  assert_success
  assert_output 1

  _run_in_container bash -c "grep '^POSTGREY_TEXT=\"Delayed by Postgrey\"$' /etc/default/postgrey | wc -l"
  assert_success
  assert_output 1
}

@test "${TEST_NAME_PREFIX} Postgrey is running" {
  run check_if_process_is_running 'postgrey'
  assert_success
}

@test "${TEST_NAME_PREFIX} there should be a log entry about a new greylisted e-mail user@external.tld in /var/log/mail/mail.log" {
  #editing the postfix config in order to ensure that postgrey handles the test e-mail. The other spam checks at smtpd_recipient_restrictions would interfere with it.
  _run_in_container bash -c "sed -ie 's/permit_sasl_authenticated.*policyd-spf,$//g' /etc/postfix/main.cf"
  _run_in_container bash -c "sed -ie 's/reject_unauth_pipelining.*reject_unknown_recipient_domain,$//g' /etc/postfix/main.cf"
  _run_in_container bash -c "sed -ie 's/reject_rbl_client.*inet:127\.0\.0\.1:10023$//g' /etc/postfix/main.cf"
  _run_in_container bash -c "sed -ie 's/smtpd_recipient_restrictions =/smtpd_recipient_restrictions = check_policy_service inet:127.0.0.1:10023/g' /etc/postfix/main.cf"
  _run_in_container postfix reload

  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/postgrey.txt"
  sleep 5 #ensure that the information has been written into the log
  _run_in_container bash -c "grep -i 'action=greylist.*user@external\.tld' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "${TEST_NAME_PREFIX} there should be a log entry about the retried and passed e-mail user@external.tld in /var/log/mail/mail.log" {
  sleep 20 #wait 20 seconds so that postgrey would accept the message
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/postgrey.txt"
  sleep 8

  _run_in_container bash -c "grep -i 'action=pass, reason=triplet found.*user@external\.tld' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "${TEST_NAME_PREFIX} there should be a log entry about the whitelisted and passed e-mail user@whitelist.tld in /var/log/mail/mail.log" {
  _run_in_container bash -c "nc -w 8 0.0.0.0 10023 < /tmp/docker-mailserver-test/nc_templates/postgrey_whitelist.txt"
  _run_in_container bash -c "grep -i 'action=pass, reason=client whitelist' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "${TEST_NAME_PREFIX} there should be a log entry about the whitelisted local and passed e-mail user@whitelistlocal.tld in /var/log/mail/mail.log" {
  _run_in_container bash -c "nc -w 8 0.0.0.0 10023 < /tmp/docker-mailserver-test/nc_templates/postgrey_whitelist_local.txt"
  _run_in_container bash -c "grep -i 'action=pass, reason=client whitelist' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "${TEST_NAME_PREFIX} there should be a log entry about the whitelisted recipient user2@otherdomain.tld in /var/log/mail/mail.log" {
  _run_in_container bash -c "nc -w 8 0.0.0.0 10023 < /tmp/docker-mailserver-test/nc_templates/postgrey_whitelist_recipients.txt"
  _run_in_container bash -c "grep -i 'action=pass, reason=recipient whitelist' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}
