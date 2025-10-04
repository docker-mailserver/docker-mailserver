load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Mail Accounts] '
CONTAINER_NAME='dms-test_accounts'

function setup_file() {
  _init_with_defaults
  _common_container_setup

  # Testing account added after start-up is also working correctly:
  _add_mail_account_then_wait_until_ready 'added@localhost.localdomain' 'mypassword'
  # Testing can create an account with potentially problematic input:
  _add_mail_account_then_wait_until_ready 'pass@localhost.localdomain' 'may be \a `p^a.*ssword'
}

function teardown_file() { _default_teardown ; }

### Account Setup ###

@test "should have created all accounts in Dovecot UserDB" {
  _run_in_container doveadm user '*'
  assert_success
  assert_line --index 0 'user1@localhost.localdomain'
  assert_line --index 1 'user2@otherdomain.tld'
  assert_line --index 2 'user3@localhost.localdomain'
  assert_line --index 3 'added@localhost.localdomain'
  assert_line --index 4 'pass@localhost.localdomain'
  assert_line --index 5 'alias1@localhost.localdomain'
  # Dovecot "dummy accounts" for quota support, see `test/config/postfix-virtual.cf` for more context
  assert_line --index 6 'prefixtest@localhost.localdomain'
  assert_line --index 7 'test@localhost.localdomain'
  assert_line --index 8 'first-name@localhost.localdomain'
  assert_line --index 9 'first.name@localhost.localdomain'
  _should_output_number_of_lines 10

  refute_line --partial '@localdomain2.com'

  # Relevant log output from scripts/helpers/accounts.sh:_create_dovecot_alias_dummy_accounts():
  # [  DEBUG  ]  Adding alias 'alias1@localhost.localdomain' for user 'user1@localhost.localdomain' to Dovecot's userdb
  # [  DEBUG  ]  Alias 'alias2@localhost.localdomain' is non-local (or mapped to a non-existing account) and will not be added to Dovecot's userdb
}

# Dovecot "dummy accounts" for quota support, see `test/config/postfix-virtual.cf` for more context
@test "should create all dovecot dummy accounts" {
  run docker logs "${CONTAINER_NAME}"
  assert_success
  assert_line --partial "Adding alias 'prefixtest@localhost.localdomain' for user 'user2@otherdomain.tld' to Dovecot's userdb"
  assert_line --partial "Adding alias 'test@localhost.localdomain' for user 'user2@otherdomain.tld' to Dovecot's userdb"
  refute_line --partial "Alias 'test@localhost.localdomain' will not be added to '/etc/dovecot/userdb' twice"

  assert_line --partial "Adding alias 'first-name@localhost.localdomain' for user 'user2@otherdomain.tld' to Dovecot's userdb"
  assert_line --partial "Adding alias 'first.name@localhost.localdomain' for user 'user2@otherdomain.tld' to Dovecot's userdb"
  refute_line --partial "Alias 'first.name@localhost.localdomain' will not be added to '/etc/dovecot/userdb' twice"
}

@test "should have created maildir for 'user1@localhost.localdomain'" {
  _run_in_container_bash '[[ -d /var/mail/localhost.localdomain/user1 ]]'
  assert_success
}

@test "should have created maildir for 'user2@otherdomain.tld'" {
  _run_in_container_bash '[[ -d /var/mail/otherdomain.tld/user2 ]]'
  assert_success
}

@test "should have created maildir for 'user3@localhost.localdomain'" {
  _run_in_container_bash '[[ -d /var/mail/localhost.localdomain/user3 ]]'
  assert_success
}

@test "should have created maildir for 'added@localhost.localdomain'" {
  _run_in_container_bash '[[ -d /var/mail/localhost.localdomain/added ]]'
  assert_success
}

@test "should not accidentally parse comments in 'postfix-accounts.cf' as accounts" {
  _should_have_content_in_directory '/var/mail'
  refute_output --partial 'comment'
}

### Account Management ###

@test "should fail to create a user when the domain-part ('@example.com') is missing" {
  _run_in_container setup email add user_without_domain mypassword
  assert_failure
  assert_output --partial 'should include the domain (eg: user@example.com)'
}

@test "should add new user 'user3@domain.tld' into 'postfix-accounts.cf'" {
  __should_add_new_user 'user3@domain.tld'
}

@test "should add new user 'USeRx@domain.tld' as 'userx@domain.tld' into 'postfix-accounts.cf' and log a warning" {
  local MAIL_ACCOUNT='USeRx@domain.tld'
  local NORMALIZED_MAIL_ACCOUNT='userx@domain.tld'

  _run_in_container setup email add "${MAIL_ACCOUNT}" mypassword
  assert_success
  assert_output --partial "'USeRx@domain.tld' has uppercase letters and will be normalized to 'userx@domain.tld'"

  __check_mail_account_exists "${NORMALIZED_MAIL_ACCOUNT}"
  assert_success
  assert_output "${NORMALIZED_MAIL_ACCOUNT}"
}

# To catch mistakes from substring matching:
@test "should add new user 'auser3@domain.tld' into 'postfix-accounts.cf'" {
  __should_add_new_user 'auser3@domain.tld'
}

# To catch mistakes from accidental pattern `.` matching as `u`:
@test "should add new user 'a.ser3@domain.tld' into 'postfix-accounts.cf'" {
  __should_add_new_user 'a.ser3@domain.tld'
}

@test "should remove user3 (but not auser3) from 'postfix-accounts.cf'" {
  # Waits until change event has created directory but not completed:
  _wait_until_account_maildir_exists 'user3@domain.tld'
  # Should trigger a new change event:
  _exec_in_container setup email del -y 'user3@domain.tld'

  # NOTE: This is only checking `postfix-accounts.cf`, account may still persist
  # elsewhere momentarily such as the Dovecot UserDB until change event kicks in.
  __check_mail_account_exists 'user3@domain.tld'
  assert_failure

  __check_mail_account_exists 'auser3@domain.tld'
  assert_success
  assert_output 'auser3@domain.tld'
}

@test "should update password for user4 by modifying entry in 'postfix-accounts.cf'" {
  # This change tends to be bundled with change detection event from previous test case
  # deleting 'user3@domain.tld', thus both changes are usually applied together.
  # NOTE: Technically these two `setup email ...` commands are run async, there is no
  # proper file locking applied to `postfix-accounts.cf`, potentially a race condition.
  _add_mail_account_then_wait_until_ready 'user4@domain.tld'

  local ORIGINAL_ENTRY UPDATED_ENTRY
  ORIGINAL_ENTRY=$(_exec_in_container grep '^user4@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf)
  _exec_in_container setup email update 'user4@domain.tld' mynewpassword
  UPDATED_ENTRY=$(_exec_in_container grep '^user4@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf)

  assert_not_equal "${ORIGINAL_ENTRY}" "${UPDATED_ENTRY}"
}

# TODO: Prone to failure sometimes from the change event in previous test case,
# as Dovecot service can be momentarily unavailable during reload?
@test "(ENV ENABLE_QUOTAS=0) 'setup email list' should not display quota information" {
  _run_in_container_bash 'echo "ENABLE_QUOTAS=0" >> /etc/dms-settings && setup email list | head -n 1'
  assert_success
  assert_output '* user1@localhost.localdomain'
}

@test "(ENV ENABLE_QUOTAS=1) 'setup email list' should display quota information" {
  _run_in_container_bash 'sed -i "/ENABLE_QUOTAS=0/d" /etc/dms-settings; setup email list | head -n 1'
  assert_success
  assert_output '* user1@localhost.localdomain ( 0 / ~ ) [0%]'
}

@test "(missing postfix-accounts.cf) 'setup email del' should not fail with an error" {
  run docker run --rm "${IMAGE_NAME:?}" setup email del -y 'user3@domain.tld'
  assert_success
  assert_output ''
}

@test "(missing postfix-accounts.cf) 'setup email add' should create 'postfix-accounts.cf' and populate with new mail account" {
  run docker run --rm "${IMAGE_NAME:?}" \
    /bin/bash -c 'setup email add user3@domain.tld mypassword && grep -o "^user3@domain\.tld" /tmp/docker-mailserver/postfix-accounts.cf'
  assert_success
  assert_output 'user3@domain.tld'
}

function __should_add_new_user() {
  local MAIL_ACCOUNT=${1}
  _exec_in_container setup email add "${MAIL_ACCOUNT}" mypassword

  __check_mail_account_exists "${MAIL_ACCOUNT}"
  assert_success
  assert_output "${MAIL_ACCOUNT}"
}

# Uses a double grep to avoid test case failures from accidental substring/pattern matching
function __check_mail_account_exists() {
  local MAIL_ACCOUNT=${1}

  # Filter out any comment lines, then truncate each line at their first `|` delimiter:
  _run_in_container_bash "sed -e '/\s*#/d' -e 's/|.*//' /tmp/docker-mailserver/postfix-accounts.cf | grep '^${MAIL_ACCOUNT}' | grep -F '${MAIL_ACCOUNT}'"
}
