load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

TEST_NAME_PREFIX='SMTP Delivery:'
CONTAINER_NAME='dms-test_smtp-delivery'

function setup_file() {
  init_with_defaults

  local CONTAINER_ARGS_ENV_CUSTOM=(
    # Required not only for authentication, but delivery in these tests (via nc):
    # TODO: Properly test with DNS records configured and separate container for
    #       handling delivery (without nc). This would remove the need for this ENV:
    --env PERMIT_DOCKER=container
    # NOTE: Authentication is rejected due to default POSTSCREEN_ACTION=enforce and PERMIT_DOCKER=none
    # Non-issue when PERMIT_DOCKER is not the default `none` for these nc 0.0.0.0 tests:
    # --env POSTSCREEN_ACTION=ignore

    # Required for test 'rejects spam':
    --env ENABLE_SPAMASSASSIN=1
    --env SPAMASSASSIN_SPAM_TO_INBOX=0

    # Only relevant for tests expecting to match `external.tld=`?:
    # `spam@external.tld` and `user@external.tld` are delivered with with the domain-part changed to `example.test`
    # https://github.com/roehling/postsrsd
    --env ENABLE_SRS=1
    # Required for ENABLE_SRS=1:
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"

    # Required for tests: 'redirects mail to external aliases' + 'rejects spam':
    --env ENABLE_AMAVIS=1

    # TODO: Relocate relevant tests to the separated clamav test file:
    # Originally relevant, but tests expecting ClamAV weren't properly implemented and didn't raise a failure.
    # --env ENABLE_CLAMAV=1
  )

  # Required for 'delivers mail to existing alias with recipient delimiter':
  mv "${TEST_TMP_CONFIG}/smtp-delivery/postfix-main.cf" "${TEST_TMP_CONFIG}/postfix-main.cf"
  mv "${TEST_TMP_CONFIG}/smtp-delivery/dovecot.cf" "${TEST_TMP_CONFIG}/dovecot.cf"

  common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  _run_in_container setup email add 'added@localhost.localdomain' 'mypassword'
  assert_success
  wait_until_change_detection_event_completes "${CONTAINER_NAME}"

  wait_for_smtp_port_in_container "${CONTAINER_NAME}"

  # TODO (move to clamav tests): For use when ClamAV is enabled:
  # repeat_in_container_until_success_or_timeout 60 "${CONTAINER_NAME}" test -e /var/run/clamav/clamd.ctl
  # _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-virus.txt"

  # Required for 'delivers mail to existing alias':
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-external.txt"
  # Required for 'delivers mail to existing alias with recipient delimiter':
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-recipient-delimiter.txt"
  # Required for 'delivers mail to existing catchall':
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-catchall-local.txt"
  # Required for 'delivers mail to regexp alias':
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-regexp-alias-local.txt"

  # Required for 'rejects mail to unknown user':
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/non-existing-user.txt"
  # Required for 'redirects mail to external aliases':
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-regexp-alias-external.txt"
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-local.txt"
  # Required for 'rejects spam':
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"

  # Required for 'delivers mail to existing account':
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user2.txt"
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user3.txt"
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-added.txt"
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user-and-cc-local-alias.txt"
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/sieve-spam-folder.txt"
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/sieve-pipe.txt"
  _run_in_container bash -c "sendmail root < /tmp/docker-mailserver-test/email-templates/root-email.txt"

  wait_for_empty_mail_queue_in_container "${CONTAINER_NAME}"
}

function teardown_file() { _default_teardown ; }

@test "checking smtp: authentication works with good password (plain)" {
  _run_in_container bash -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-plain.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking smtp: authentication fails with wrong password (plain)" {
  _run_in_container bash -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-plain-wrong.txt"
  assert_output --partial 'authentication failed'
  assert_success
}

@test "checking smtp: authentication works with good password (login)" {
  _run_in_container bash -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking smtp: authentication fails with wrong password (login)" {
  _run_in_container bash -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt"
  assert_output --partial 'authentication failed'
  assert_success
}

@test "checking smtp: added user authentication works with good password (plain)" {
  _run_in_container bash -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-plain.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking smtp: added user authentication fails with wrong password (plain)" {
  _run_in_container bash -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-plain-wrong.txt | grep 'authentication failed'"
  assert_success
}

@test "checking smtp: added user authentication works with good password (login)" {
  _run_in_container bash -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-login.txt | grep 'Authentication successful'"
  assert_success
}

@test "checking smtp: added user authentication fails with wrong password (login)" {
  _run_in_container bash -c "nc -w 20 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/added-smtp-auth-login-wrong.txt | grep 'authentication failed'"
  assert_success
}

# TODO add a test covering case SPAMASSASSIN_SPAM_TO_INBOX=1 (default)
@test "checking smtp: delivers mail to existing account" {
  _run_in_container bash -c "grep 'postfix/lmtp' /var/log/mail/mail.log | grep 'status=sent' | grep ' Saved)' | sed 's/.* to=</</g' | sed 's/, relay.*//g' | sort | uniq -c | tr -s \" \""
  assert_success
  assert_output <<'EOF'
 1 <added@localhost.localdomain>
 6 <user1@localhost.localdomain>
 1 <user1@localhost.localdomain>, orig_to=<postmaster@example.test>
 1 <user1@localhost.localdomain>, orig_to=<root>
 1 <user1~test@localhost.localdomain>
 2 <user2@otherdomain.tld>
 1 <user3@localhost.localdomain>
EOF
}

@test "checking smtp: delivers mail to existing alias" {
  _run_in_container bash -c "grep 'to=<user1@localhost.localdomain>, orig_to=<alias1@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to existing alias with recipient delimiter" {
  _run_in_container bash -c "grep 'to=<user1~test@localhost.localdomain>, orig_to=<alias1~test@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1

  _run_in_container bash -c "grep 'to=<user1~test@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=bounced'"
  assert_failure
}

@test "checking smtp: delivers mail to existing catchall" {
  _run_in_container bash -c "grep 'to=<user1@localhost.localdomain>, orig_to=<wildcard@localdomain2.com>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: delivers mail to regexp alias" {
  _run_in_container bash -c "grep 'to=<user1@localhost.localdomain>, orig_to=<test123@localhost.localdomain>' /var/log/mail/mail.log | grep 'status=sent' | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: user1 should have received 9 mails" {
  _run_in_container bash -c "grep Subject /var/mail/localhost.localdomain/user1/new/* | sed 's/.*Subject: //g' | sed 's/\.txt.*//g' | sed 's/VIRUS.*/VIRUS/g' | sort"
  assert_success
  # 9 messages, the virus mail has three subject lines
  cat <<'EOF' | assert_output
Root Test Message
Test Message amavis-virus
Test Message amavis-virus
Test Message existing-alias-external
Test Message existing-alias-recipient-delimiter
Test Message existing-catchall-local
Test Message existing-regexp-alias-local
Test Message existing-user-and-cc-local-alias
Test Message existing-user1
Test Message sieve-spam-folder
VIRUS
EOF
}

@test "checking smtp: rejects mail to unknown user" {
  _run_in_container bash -c "grep '<nouser@localhost.localdomain>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail/mail.log | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: redirects mail to external aliases" {
  _run_in_container bash -c "grep -- '-> <external1@otherdomain.tld>' /var/log/mail/mail.log* | grep RelayedInbound | wc -l"
  assert_success
  assert_output 2
}

# TODO add a test covering case SPAMASSASSIN_SPAM_TO_INBOX=1 (default)
@test "checking smtp: rejects spam" {
  _run_in_container bash -c "grep 'Blocked SPAM' /var/log/mail/mail.log | grep external.tld=spam@example.test | wc -l"
  assert_success
  assert_output 1
}

@test "checking smtp: not advertising smtputf8" {
  # Dovecot does not support SMTPUTF8, so while we can send we cannot receive
  # Better disable SMTPUTF8 support entirely if we can't handle it correctly
  _run_in_container bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/smtp-ehlo.txt | grep SMTPUTF8 | wc -l"
  assert_success
  assert_output 0
}

@test "checking that mail for root was delivered" {
  _run_in_container grep "Subject: Root Test Message" /var/mail/localhost.localdomain/user1/new/ -R
  assert_success
}
