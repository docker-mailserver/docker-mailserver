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

@test "accounts: user accounts" {
  _run_in_container doveadm user '*'
  assert_success
  assert_line --index 0 "user1@localhost.localdomain"
  assert_line --index 1 "user2@otherdomain.tld"
  assert_line --index 2 "user3@localhost.localdomain"
  assert_line --index 3 "added@localhost.localdomain"
}

@test "accounts: user mail folder for user1" {
  _run_in_container_bash "ls -d /var/mail/localhost.localdomain/user1"
  assert_success
}

@test "accounts: user mail folder for user2" {
  _run_in_container_bash "ls -d /var/mail/otherdomain.tld/user2"
  assert_success
}

@test "accounts: user mail folder for user3" {
  _run_in_container_bash "ls -d /var/mail/localhost.localdomain/user3"
  assert_success
}

@test "accounts: user mail folder for added user" {
  _run_in_container_bash "ls -d /var/mail/localhost.localdomain/added"
  assert_success
}

@test "accounts: comments are not parsed" {
  _run_in_container_bash "ls /var/mail | grep 'comment'"
  assert_failure
}

@test "accounts: user_without_domain creation should be rejected since user@domain format is required" {
  _run_in_container_bash "addmailuser user_without_domain mypassword"
  assert_failure
  assert_output --partial 'should include the domain (eg: user@example.com)'
}

@test "accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  _exec_in_container_bash "addmailuser user3@domain.tld mypassword"

  _run_in_container_bash "grep '^user3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [[ -n ${output} ]]
}

@test "accounts: auser3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  _exec_in_container_bash "addmailuser auser3@domain.tld mypassword"

  _run_in_container_bash "grep '^auser3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [[ -n ${output} ]]
}

@test "accounts: a.ser3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf" {
  _exec_in_container_bash "addmailuser a.ser3@domain.tld mypassword"

  _run_in_container_bash "grep '^a\.ser3@domain\.tld|' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [[ -n ${output} ]]
}

@test "accounts: user3 should have been removed from /tmp/docker-mailserver/postfix-accounts.cf but not auser3" {
  _wait_until_account_maildir_exists 'user3@domain.tld'

  _exec_in_container_bash "delmailuser -y user3@domain.tld"

  _run_in_container_bash "grep '^user3@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_failure
  [[ -z ${output} ]]

  _run_in_container_bash "grep '^auser3@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf"
  assert_success
  [[ -n ${output} ]]
}

@test "user updating password for user in /tmp/docker-mailserver/postfix-accounts.cf" {
  _add_mail_account_then_wait_until_ready 'user4@domain.tld'

  initialpass=$(_exec_in_container_bash "grep '^user4@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf")
  sleep 2
  _exec_in_container_bash "updatemailuser user4@domain.tld mynewpassword"
  sleep 2
  changepass=$(_exec_in_container_bash "grep '^user4@domain\.tld' -i /tmp/docker-mailserver/postfix-accounts.cf")

  [[ ${initialpass} != "${changepass}" ]]

  _run_in_container_bash "delmailuser -y auser3@domain.tld"
  assert_success
}

@test "accounts: listmailuser (quotas disabled)" {
  _run_in_container_bash "echo 'ENABLE_QUOTAS=0' >> /etc/dms-settings && listmailuser | head -n 1"
  assert_success
  assert_output '* user1@localhost.localdomain'
}

@test "accounts: listmailuser (quotas enabled)" {
  _run_in_container_bash "sed -i '/ENABLE_QUOTAS=0/d' /etc/dms-settings; listmailuser | head -n 1"
  assert_success
  assert_output '* user1@localhost.localdomain ( 0 / ~ ) [0%]'
}

@test "accounts: no error is generated when deleting a user if /tmp/docker-mailserver/postfix-accounts.cf is missing" {
  run docker run --rm \
    -v "$(_duplicate_config_for_container without-accounts/ without-accounts-deleting-user)":/tmp/docker-mailserver/ \
    "${IMAGE_NAME:?}" /bin/sh -c 'delmailuser -y user3@domain.tld'
  assert_success
  [[ -z ${output} ]]
}

@test "accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf even when that file does not exist" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(_duplicate_config_for_container without-accounts/ without-accounts_file_does_not_exist)
  run docker run --rm \
    -v "${PRIVATE_CONFIG}/without-accounts/":/tmp/docker-mailserver/ \
    "${IMAGE_NAME:?}" /bin/sh -c 'addmailuser user3@domain.tld mypassword'
  assert_success
  run docker run --rm \
    -v "${PRIVATE_CONFIG}/without-accounts/":/tmp/docker-mailserver/ \
    "${IMAGE_NAME:?}" /bin/sh -c 'grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf'
  assert_success
  [[ -n ${output} ]]
}
