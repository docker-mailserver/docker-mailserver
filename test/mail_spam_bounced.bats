load 'test_helper/common'

# Test case
# ---------
# When SPAMASSASSIN_SPAM_TO_INBOX=0, spam messages must be bounced (rejected).
# SPAMASSASSIN_SPAM_TO_INBOX=1 is covered in `mail_spam_junk_folder.bats`.
# Original test PR: https://github.com/docker-mailserver/docker-mailserver/pull/1485

# TODO: ENV setup will move to actual ENV files in future.

function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  docker rm -f "${TEST_NAME}"
  run_teardown_file_if_necessary
}

function setup_file() {
  init_with_defaults
}

# Not used
# function teardown_file() {
# }

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking amavis: spam message is bounced (rejected)" {
  local TEST_ENV_FILE="${PRIVATE_CONFIG}/defined.env"
  echo 'ENABLE_SPAMASSASSIN=1' > "${TEST_ENV_FILE}"
  echo 'SPAMASSASSIN_SPAM_TO_INBOX=0' >> "${TEST_ENV_FILE}"

  common_container_setup "${TEST_ENV_FILE}"

  run _should_emit_warning
  assert_failure

  _should_bounce_spam
}

@test "checking amavis: spam message is bounced (rejected), undefined SPAMASSASSIN_SPAM_TO_INBOX should raise a warning" {
  # SPAMASSASSIN_SPAM_TO_INBOX=0 is the default. If no explicit ENV value is set, it should log a warning at startup.
  local TEST_ENV_FILE="${PRIVATE_CONFIG}/undefined.env"
  echo 'ENABLE_SPAMASSASSIN=1' > "${TEST_ENV_FILE}"

  common_container_setup "${TEST_ENV_FILE}"

  run _should_emit_warning
  assert_success

  _should_bounce_spam
}

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}

# This warning should only be raised when the env SPAMASSASSIN_SPAM_TO_INBOX has no explicit value set
function _should_emit_warning() {
  sh -c "docker logs ${TEST_NAME} | grep 'Spam messages WILL NOT BE DELIVERED'"
}

function _should_bounce_spam() {
  wait_for_smtp_port_in_container_to_respond "${TEST_NAME}"

  # send a spam message
  run docker exec "${TEST_NAME}" /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  run repeat_until_success_or_timeout 20 sh -c "docker logs ${TEST_NAME} | grep 'Blocked SPAM {NoBounceInbound,Quarantined}'"
  assert_success
}
