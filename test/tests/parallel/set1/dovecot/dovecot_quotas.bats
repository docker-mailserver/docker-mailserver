load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Dovecot Quotas] '
CONTAINER_NAME='dms-test_dovecot-quotas'

function setup_file() {
  _init_with_defaults

  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env ENABLE_QUOTAS=1
    --env PERMIT_DOCKER=container
  )
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'
}

function teardown_file() { _default_teardown ; }

@test 'should only support setting quota for a valid account' {
  # Prepare
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  # Actual tests
  _run_in_container_bash "setup quota set quota_user 50M"
  assert_failure

  _run_in_container_bash "setup quota set username@fulldomain 50M"
  assert_failure

  _run_in_container_bash "setup quota set quota_user@domain.tld 50M"
  assert_success

  # Cleanup
  _run_in_container_bash "setup email del -y quota_user@domain.tld"
  assert_success
}

@test 'should only allow valid units as quota size' {
  # Prepare
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  # Actual tests
  _run_in_container_bash "setup quota set quota_user@domain.tld 26GIGOTS"
  assert_failure
  _run_in_container_bash "setup quota set quota_user@domain.tld 123"
  assert_failure
  _run_in_container_bash "setup quota set quota_user@domain.tld M"
  assert_failure
  _run_in_container_bash "setup quota set quota_user@domain.tld -60M"
  assert_failure


  _run_in_container_bash "setup quota set quota_user@domain.tld 10B"
  assert_success
  _run_in_container_bash "setup quota set quota_user@domain.tld 10k"
  assert_success
  _run_in_container_bash "setup quota set quota_user@domain.tld 10M"
  assert_success
  _run_in_container_bash "setup quota set quota_user@domain.tld 10G"
  assert_success
  _run_in_container_bash "setup quota set quota_user@domain.tld 10T"
  assert_success

  # Cleanup
  _run_in_container_bash "setup email del -y quota_user@domain.tld"
  assert_success
}

@test 'should only support removing quota from a valid account' {
  # Prepare
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  # Actual tests
  _run_in_container_bash "setup quota del uota_user@domain.tld"
  assert_failure
  _run_in_container_bash "setup quota del quota_user"
  assert_failure
  _run_in_container_bash "setup quota del dontknowyou@domain.tld"
  assert_failure

  _run_in_container_bash "setup quota set quota_user@domain.tld 10T"
  assert_success
  _run_in_container_bash "setup quota del quota_user@domain.tld"
  assert_success
  _run_in_container_bash "grep -i 'quota_user@domain.tld' /tmp/docker-mailserver/dovecot-quotas.cf"
  assert_failure

  # Cleanup
  _run_in_container_bash "setup email del -y quota_user@domain.tld"
  assert_success
}

@test 'should not error when there is no quota to remove for an account' {
  # Prepare
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  # Actual tests
  _run_in_container_bash "grep -i 'quota_user@domain.tld' /tmp/docker-mailserver/dovecot-quotas.cf"
  assert_failure

  _run_in_container_bash "setup quota del quota_user@domain.tld"
  assert_success
  _run_in_container_bash "setup quota del quota_user@domain.tld"
  assert_success

  # Cleanup
  _run_in_container_bash "setup email del -y quota_user@domain.tld"
  assert_success
}

@test 'should have configured Postfix to use the Dovecot quota-status service' {
  _run_in_container_bash "postconf | grep 'check_policy_service inet:localhost:65265'"
  assert_success
}


@test '(mailbox max size) should be equal for both Postfix and Dovecot' {
  postfix_mailbox_size=$(_exec_in_container_bash "postconf | grep -Po '(?<=mailbox_size_limit = )[0-9]+'")
  run echo "${postfix_mailbox_size}"
  refute_output ""

  # dovecot relies on virtual_mailbox_size by default
  postfix_virtual_mailbox_size=$(_exec_in_container_bash "postconf | grep -Po '(?<=virtual_mailbox_limit = )[0-9]+'")
  assert_equal "${postfix_virtual_mailbox_size}" "${postfix_mailbox_size}"

  postfix_mailbox_size_mb=$(( postfix_mailbox_size / 1000000))

  dovecot_mailbox_size_mb=$(_exec_in_container_bash "doveconf | grep  -oP '(?<=quota_rule \= \*\:storage=)[0-9]+'")
  run echo "${dovecot_mailbox_size_mb}"
  refute_output ""

  assert_equal "${postfix_mailbox_size_mb}" "${dovecot_mailbox_size_mb}"
}


@test '(message max size) should be equal for both Postfix and Dovecot' {
  postfix_message_size=$(_exec_in_container_bash "postconf | grep -Po '(?<=message_size_limit = )[0-9]+'")
  run echo "${postfix_message_size}"
  refute_output ""

  postfix_message_size_mb=$(( postfix_message_size / 1000000))

  dovecot_message_size_mb=$(_exec_in_container_bash "doveconf | grep  -oP '(?<=quota_max_mail_size = )[0-9]+'")
  run echo "${dovecot_message_size_mb}"
  refute_output ""

  assert_equal "${postfix_message_size_mb}" "${dovecot_message_size_mb}"
}

@test 'Deleting an mailbox account should also remove that account from dovecot-quotas.cf' {
  _add_mail_account_then_wait_until_ready 'quserremoved@domain.tld'

  _run_in_container_bash "setup quota set quserremoved@domain.tld 12M"
  assert_success

  _run_in_container_bash 'cat /tmp/docker-mailserver/dovecot-quotas.cf | grep -E "^quserremoved@domain.tld\:12M\$" | wc -l | grep 1'
  assert_success

  _run_in_container_bash "setup email del -y quserremoved@domain.tld"
  assert_success

  _run_in_container_bash 'cat /tmp/docker-mailserver/dovecot-quotas.cf | grep -E "^quserremoved@domain.tld\:12M\$"'
  assert_failure
}

@test 'Dovecot should acknowledge quota configured for accounts' {
  _run_in_container_bash "doveadm quota get -u 'user1@localhost.localdomain' | grep 'User quota STORAGE'"
  assert_output --partial "-                         0"

  _run_in_container_bash "setup quota set user1@localhost.localdomain 50M"
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'doveadm quota get -u user1@localhost.localdomain | grep -oP "(User quota STORAGE\s+[0-9]+\s+)51200(.*)"'
  assert_success

  _run_in_container_bash "setup quota del user1@localhost.localdomain"
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'doveadm quota get -u user1@localhost.localdomain | grep -oP "(User quota STORAGE\s+[0-9]+\s+)-(.*)"'
  assert_success
}

@test 'should receive a warning mail from Dovecot when quota is exceeded' {
  skip 'disabled as it fails randomly: https://github.com/docker-mailserver/docker-mailserver/pull/2511'

  # Prepare
  _add_mail_account_then_wait_until_ready 'quotauser@otherdomain.tld'

  # Actual tests
  _run_in_container_bash 'setup quota set quotauser@otherdomain.tld 10k'
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'doveadm quota get -u quotauser@otherdomain.tld | grep -oP \"(User quota STORAGE\s+[0-9]+\s+)10(.*)\"'
  assert_success

  # dovecot and postfix has been restarted
  _wait_for_service postfix
  _wait_for_service dovecot
  sleep 10

  # send some big emails
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/quota-exceeded.txt"
  assert_success
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/quota-exceeded.txt"
  assert_success
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/quota-exceeded.txt"
  assert_success
  # check for quota warn message existence
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'grep \"Subject: quota warning\" /var/mail/otherdomain.tld/quotauser/new/ -R'
  assert_success

  run _repeat_until_success_or_timeout 20 sh -c "docker logs mail | grep 'Quota exceeded (mailbox for user is full)'"
  assert_success

  # ensure only the first big message and the warn message are present (other messages are rejected: mailbox is full)
  _run_in_container sh -c 'ls /var/mail/otherdomain.tld/quotauser/new/ | wc -l'
  assert_success
  assert_output "2"

  # Cleanup
  _run_in_container_bash "setup email del -y quotauser@otherdomain.tld"
  assert_success
}
