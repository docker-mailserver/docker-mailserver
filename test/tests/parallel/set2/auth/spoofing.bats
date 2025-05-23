load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Postfix] (sender spoofing) '
CONTAINER_NAME='dms-test_postfix-spoofing'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env SPOOF_PROTECTION=1
    --env LOG_LEVEL=trace
    --env SSL_TYPE='snakeoil'
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _wait_for_service postfix
  _wait_for_smtp_port_in_container_to_respond
}

function teardown_file() { _default_teardown ; }

# These tests ensure spoofing protection works, and that exceptions are available for aliases.
# user1 has aliases configured for the following accounts:
# - test\d* via /etc/postfix/regexp
# - alias1@localhost via /etc/postfix/virtual
# - user3@localhost via /etc/postfix/regexp-send-only

@test "allows forging as send-only alias" {
  # An authenticated account should be able to send mail from a send-only alias,
  # Verifies `main.cf:smtpd_sender_login_maps` includes /etc/postfix/regexp-send-only
  _send_email \
    --port 587 -tls --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --ehlo mail \
    --from user3@localhost.localdomain \
    --data 'auth/added-smtp-auth-spoofed-from-user3.txt'
  assert_success
  assert_output --partial 'End data with'
}

@test "allows forging as regular alias" {
  # An authenticated account should be able to send mail from an alias,
  # Verifies `main.cf:smtpd_sender_login_maps` includes /etc/postfix/virtual
  _send_email \
    --port 587 -tls --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --ehlo mail \
    --from alias1@localhost.localdomain \
    --data 'auth/added-smtp-auth-spoofed-from-alias1.txt'
  assert_success
  assert_output --partial 'End data with'
}

@test "allows forging as regular (regex) alias" {
  # An authenticated account should be able to send mail from an alias,
  # Verifies `main.cf:smtpd_sender_login_maps` includes /etc/postfix/regexp
  _send_email \
    --port 587 -tls --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --ehlo mail \
    --from test123@localhost.localdomain \
    --data 'auth/added-smtp-auth-spoofed-from-test123.txt'
  assert_success
  assert_output --partial 'End data with'
}

@test "rejects sender forging" {
  # An authenticated user cannot use an envelope sender (MAIL FROM)
  # address they do not own according to `main.cf:smtpd_sender_login_maps` lookup
  _send_email --expect-rejection \
    --port 587 -tls --auth PLAIN \
    --auth-user user3@localhost.localdomain \
    --auth-password mypassword \
    --ehlo mail \
    --from user1@localhost.localdomain \
    --data 'auth/added-smtp-auth-spoofed-from-user1.txt'
  assert_output --partial 'Sender address rejected: not owned by user'
}

@test "send-only alias does not affect incoming mail" {
  # user1 is allowed to send as user3, however, mail to user3 should still be delivered to user3.
  # Verifies that /etc/postfix/regexp-send-only does not affect incoming mail.
  _send_email \
    --port 587 -tls --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --ehlo mail \
    --from user1@localhost.localdomain \
    --to user3@localhost.localdomain \
    --data 'test-email.txt'
  assert_success
  assert_output --partial 'End data with'

  _wait_for_empty_mail_queue_in_container

  # would have an orig_to if it got forwarded
  _service_log_should_contain_string 'mail' ': to=<user3@localhost.localdomain>'
  assert_output --partial 'status=sent'
  _should_output_number_of_lines 1
}
