load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/change-detection"
load "${REPOSITORY_ROOT}/test/helper/setup"

# Regression test for https://github.com/docker-mailserver/docker-mailserver/issues/4856
#
# Postfix resolves virtual aliases before mailboxes, so the catch-all `@localdomain2.com` (from `test/config/postfix-virtual.cf`)
# would capture the mail of accounts on that domain. DMS adds an alias to itself for each account to prevent this.

BATS_TEST_NAME_PREFIX='[Catch-all] '
CONTAINER_NAME='dms-test_catch-all'

function setup_file() {
  _init_with_defaults

  # An account on the catch-all domain that exists at startup (reuses the password hash of user1):
  local USER1_ENTRY
  USER1_ENTRY=$(head -n 1 "${TEST_TMP_CONFIG}/postfix-accounts.cf")
  echo "startup@localdomain2.com|${USER1_ENTRY#*|}" >>"${TEST_TMP_CONFIG}/postfix-accounts.cf"

  local CONTAINER_ARGS_ENV_CUSTOM=(
    # Required for mail delivery via swaks:
    --env DMS_TRUSTED_NETWORKS=host
  )
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  # An account on the catch-all domain that is added at runtime (change detection):
  _wait_for_service changedetector
  _run_in_container setup email add 'added@localdomain2.com' 'mypassword'
  assert_success
  _wait_until_change_detection_event_completes

  _wait_for_smtp_port_in_container_to_respond

  _send_email --to 'startup@localdomain2.com' --header 'Subject: Test Message account-at-startup'
  _send_email --to 'added@localdomain2.com' --header 'Subject: Test Message account-added'
  _send_email --to 'wildcard@localdomain2.com' --header 'Subject: Test Message catch-all'

  _wait_for_empty_mail_queue_in_container
}

function teardown_file() { _default_teardown ; }

@test "should deliver mail to an account that exists at startup, not to the catch-all target" {
  _count_files_in_directory_in_container /var/mail/localdomain2.com/startup/new 1
}

@test "should deliver mail to an account that was added at runtime, not to the catch-all target" {
  _count_files_in_directory_in_container /var/mail/localdomain2.com/added/new 1
}

# `user1` is the catch-all target, it must not have received the mail of the two accounts above:
@test "should deliver mail to other addresses of the domain to the catch-all target" {
  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new 1

  _service_log_should_contain_string 'mail' 'to=<user1@localhost.localdomain>, orig_to=<wildcard@localdomain2.com>'
}

@test "should add the alias to itself for accounts on a catch-all domain to '/etc/postfix/virtual' only" {
  _run_in_container grep --fixed-strings '@localdomain2.com' /etc/postfix/virtual
  assert_success
  assert_line '@localdomain2.com user1@localhost.localdomain'
  assert_line 'startup@localdomain2.com startup@localdomain2.com'
  assert_line 'added@localdomain2.com added@localdomain2.com'

  _run_in_container grep --fixed-strings '@localdomain2.com' /tmp/docker-mailserver/postfix-virtual.cf
  assert_success
  assert_output '@localdomain2.com user1@localhost.localdomain'
}

@test "should not add an alias to itself for accounts on a domain without a catch-all" {
  _run_in_container grep --line-regexp --fixed-strings 'user1@localhost.localdomain user1@localhost.localdomain' /etc/postfix/virtual
  assert_failure
}
