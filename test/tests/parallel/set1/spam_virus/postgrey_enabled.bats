load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Postgrey] (enabled) '
CONTAINER_NAME='dms-test_postgrey_enabled'

function setup_file() {
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_POSTGREY=1
    --env PERMIT_DOCKER=container
    --env POSTGREY_AUTO_WHITELIST_CLIENTS=5
    --env POSTGREY_DELAY=3
    --env POSTGREY_MAX_AGE=35
    --env POSTGREY_TEXT="Delayed by Postgrey"
  )

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Postfix needs to be ready on port 25 for nc usage below:
  _wait_for_smtp_port_in_container
}

function teardown_file() { _default_teardown ; }

@test "should have added Postgrey to 'main.cf:check_policy_service'" {
  _run_in_container grep -F 'check_policy_service inet:127.0.0.1:10023' /etc/postfix/main.cf
  assert_success
  _should_output_number_of_lines 1
}

@test "should have configured /etc/default/postgrey with default values and ENV overrides" {
  _run_in_container grep -F 'POSTGREY_OPTS="--inet=127.0.0.1:10023 --delay=3 --max-age=35 --auto-whitelist-clients=5"' /etc/default/postgrey
  assert_success
  _should_output_number_of_lines 1

  _run_in_container grep -F 'POSTGREY_TEXT="Delayed by Postgrey"' /etc/default/postgrey
  assert_success
  _should_output_number_of_lines 1
}

@test "should initially reject (greylist) mail from 'user@external.tld'" {
  # Modify the postfix config in order to ensure that postgrey handles the test e-mail.
  # The other spam checks in `main.cf:smtpd_recipient_restrictions` would interfere with testing postgrey.
  _run_in_container sed -i \
    -e 's/permit_sasl_authenticated.*policyd-spf,$//g' \
    -e 's/reject_unauth_pipelining.*reject_unknown_recipient_domain,$//g' \
    -e 's/reject_rbl_client.*inet:127\.0\.0\.1:10023$//g' \
    -e 's/smtpd_recipient_restrictions =/smtpd_recipient_restrictions = check_policy_service inet:127.0.0.1:10023/g' \
    /etc/postfix/main.cf
  _reload_postfix

  # Send test mail (it should fail to deliver):
  _send_test_mail '/tmp/docker-mailserver-test/email-templates/postgrey.txt' '25'

  # Confirm mail was greylisted:
  _should_have_log_entry \
    'action=greylist' \
    'reason=new' \
    'client_address=127.0.0.1, sender=user@external.tld, recipient=user1@localhost.localdomain'

  _repeat_until_success_or_timeout 10 _run_in_container grep \
    'Recipient address rejected: Delayed by Postgrey' \
    /var/log/mail/mail.log
}

# NOTE: This test case depends on the previous one
@test "should accept mail from 'user@external.tld' after POSTGREY_DELAY duration" {
  # Wait until `$POSTGREY_DELAY` seconds pass before trying again:
  sleep 3
  # Retry delivering test mail (it should be trusted this time):
  _send_test_mail '/tmp/docker-mailserver-test/email-templates/postgrey.txt' '25'

  # Confirm postgrey permitted delivery (triplet is now trusted):
  _should_have_log_entry \
    'action=pass' \
    'reason=triplet found' \
    'client_address=127.0.0.1, sender=user@external.tld, recipient=user1@localhost.localdomain'
}


# NOTE: These two whitelist tests use `test-files/nc_templates/` instead of `test-files/email-templates`.
# - This allows to bypass the SMTP protocol on port 25, and send data directly to Postgrey instead.
# - Appears to be a workaround due to `client_name=localhost` when sent from Postfix.
# - Could send over port 25 if whitelisting `localhost`,
#   - However this does not help verify that the actual client HELO address is properly whitelisted?
#   - It'd also cause the earlier greylist test to fail.
# - TODO: Actually confirm whitelist feature works correctly as these test cases are using a workaround:
@test "should whitelist sender 'user@whitelist.tld'" {
  _send_test_mail '/tmp/docker-mailserver-test/nc_templates/postgrey_whitelist.txt' '10023'

  _should_have_log_entry \
    'action=pass' \
    'reason=client whitelist' \
    'client_address=127.0.0.1, sender=test@whitelist.tld, recipient=user1@localhost.localdomain'
}

@test "should whitelist recipient 'user2@otherdomain.tld'" {
  _send_test_mail '/tmp/docker-mailserver-test/nc_templates/postgrey_whitelist_recipients.txt' '10023'

  _should_have_log_entry \
    'action=pass' \
    'reason=recipient whitelist' \
    'client_address=127.0.0.1, sender=test@nonwhitelist.tld, recipient=user2@otherdomain.tld'
}

function _send_test_mail() {
  local MAIL_TEMPLATE=$1
  local PORT=${2:-25}

  # `-w 0` terminates the connection after sending the template, it does not wait for a response.
  # This is required for port 10023, otherwise the connection never drops.
  # It could increase the number of seconds to wait for port 25 to allow for asserting a response,
  # but that would enforce the delay in tests for port 10023.
  _run_in_container_bash "nc -w 0 0.0.0.0 ${PORT} < ${MAIL_TEMPLATE}"
}

function _should_have_log_entry() {
  local ACTION=$1
  local REASON=$2
  local TRIPLET=$3

  # Allow some extra time for logs to update to avoids a false-positive failure:
  _run_until_success_or_timeout 10 _exec_in_container grep \
    "${ACTION}, ${REASON}," \
    /var/log/mail/mail.log

  # Log entry matched should be for the expected triplet:
  assert_output --partial "${TRIPLET}"
  _should_output_number_of_lines 1
}

# `lines` is a special BATS variable updated via `run`:
function _should_output_number_of_lines() {
  assert_equal "${#lines[@]}" "${1}"
}
