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
  _run_in_container setup quota set quota_user 50M
  assert_failure

  _run_in_container setup quota set username@fulldomain 50M
  assert_failure

  _run_in_container setup quota set quota_user@domain.tld 50M
  assert_success

  # Cleanup
  _run_in_container setup email del -y quota_user@domain.tld
  assert_success
}

@test 'should only allow valid units as quota size' {
  # Prepare
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  # Actual tests
  _run_in_container setup quota set quota_user@domain.tld 26GIGOTS
  assert_failure
  _run_in_container setup quota set quota_user@domain.tld 123
  assert_failure
  _run_in_container setup quota set quota_user@domain.tld M
  assert_failure
  _run_in_container setup quota set quota_user@domain.tld -60M
  assert_failure


  _run_in_container setup quota set quota_user@domain.tld 10B
  assert_success
  _run_in_container setup quota set quota_user@domain.tld 10k
  assert_success
  _run_in_container setup quota set quota_user@domain.tld 10M
  assert_success
  _run_in_container setup quota set quota_user@domain.tld 10G
  assert_success
  _run_in_container setup quota set quota_user@domain.tld 10T
  assert_success

  # Cleanup
  _run_in_container setup email del -y quota_user@domain.tld
  assert_success
}

@test 'should only support removing quota from a valid account' {
  # Prepare
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  # Actual tests
  _run_in_container setup quota del uota_user@domain.tld
  assert_failure
  _run_in_container setup quota del quota_user
  assert_failure
  _run_in_container setup quota del dontknowyou@domain.tld
  assert_failure

  _run_in_container setup quota set quota_user@domain.tld 10T
  assert_success
  _run_in_container setup quota del quota_user@domain.tld
  assert_success
  _run_in_container grep -i 'quota_user@domain.tld' /tmp/docker-mailserver/dovecot-quotas.cf
  assert_failure

  # Cleanup
  _run_in_container setup email del -y quota_user@domain.tld
  assert_success
}

@test 'should not error when there is no quota to remove for an account' {
  # Prepare
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  # Actual tests
  _run_in_container grep -i 'quota_user@domain.tld' /tmp/docker-mailserver/dovecot-quotas.cf
  assert_failure

  _run_in_container setup quota del quota_user@domain.tld
  assert_success
  _run_in_container setup quota del quota_user@domain.tld
  assert_success

  # Cleanup
  _run_in_container setup email del -y quota_user@domain.tld
  assert_success
}

@test 'should have configured Postfix to use the Dovecot quota-status service' {
  _run_in_container postconf
  assert_success
  assert_output --partial 'check_policy_service inet:localhost:65265'
}

@test '(ENV POSTFIX_MAILBOX_SIZE_LIMIT) should be configured for both Postfix and Dovecot' {
  local MAILBOX_SIZE_POSTFIX MAILBOX_SIZE_DOVECOT MAILBOX_SIZE_POSTFIX_MB MAILBOX_SIZE_DOVECOT_MB

  MAILBOX_SIZE_POSTFIX=$(_exec_in_container postconf -h mailbox_size_limit)
  run echo "${MAILBOX_SIZE_POSTFIX}"
  refute_output ""

  # Dovecot mailbox is sized by `virtual_mailbox_size` from Postfix:
  MAILBOX_SIZE_DOVECOT=$(_exec_in_container postconf -h virtual_mailbox_limit)
  assert_equal "${MAILBOX_SIZE_DOVECOT}" "${MAILBOX_SIZE_POSTFIX}"

  # Quota support:
  MAILBOX_SIZE_POSTFIX_MB=$(( MAILBOX_SIZE_POSTFIX / 1000000))
  MAILBOX_SIZE_DOVECOT_MB=$(_exec_in_container_bash 'doveconf -h plugin/quota_rule | grep -oE "[0-9]+"')
  run echo "${MAILBOX_SIZE_DOVECOT_MB}"
  refute_output ""

  assert_equal "${MAILBOX_SIZE_POSTFIX_MB}" "${MAILBOX_SIZE_DOVECOT_MB}"
}

@test '(ENV POSTFIX_MESSAGE_SIZE_LIMIT) should be configured for both Postfix and Dovecot' {
  local MESSAGE_SIZE_POSTFIX MESSAGE_SIZE_POSTFIX_MB MESSAGE_SIZE_DOVECOT_MB

  MESSAGE_SIZE_POSTFIX=$(_exec_in_container postconf -h message_size_limit)
  run echo "${MESSAGE_SIZE_POSTFIX}"
  refute_output ""

  # Quota support:
  MESSAGE_SIZE_POSTFIX_MB=$(( MESSAGE_SIZE_POSTFIX / 1000000))
  MESSAGE_SIZE_DOVECOT_MB=$(_exec_in_container_bash 'doveconf -h plugin/quota_max_mail_size | grep -oE "[0-9]+"')
  run echo "${MESSAGE_SIZE_DOVECOT_MB}"
  refute_output ""

  assert_equal "${MESSAGE_SIZE_POSTFIX_MB}" "${MESSAGE_SIZE_DOVECOT_MB}"
}

@test 'Deleting an mailbox account should also remove that account from dovecot-quotas.cf' {
  _add_mail_account_then_wait_until_ready 'quserremoved@domain.tld'

  _run_in_container setup quota set quserremoved@domain.tld 12M
  assert_success

  _run_in_container cat '/tmp/docker-mailserver/dovecot-quotas.cf'
  assert_success
  assert_output 'quserremoved@domain.tld:12M'

  _run_in_container setup email del -y quserremoved@domain.tld
  assert_success

  _run_in_container cat /tmp/docker-mailserver/dovecot-quotas.cf
  assert_success
  refute_output --partial 'quserremoved@domain.tld:12M'
}

@test 'Dovecot should acknowledge quota configured for accounts' {
  _run_in_container_bash "doveadm quota get -u 'user1@localhost.localdomain' | grep 'User quota STORAGE'"
  assert_output --partial "-                         0"

  _run_in_container setup quota set user1@localhost.localdomain 50M
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'doveadm quota get -u user1@localhost.localdomain | grep -oP "(User quota STORAGE\s+[0-9]+\s+)51200(.*)"'
  assert_success

  _run_in_container setup quota del user1@localhost.localdomain
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
  _run_in_container setup quota set quotauser@otherdomain.tld 10k
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'doveadm quota get -u quotauser@otherdomain.tld | grep -oP "(User quota STORAGE\s+[0-9]+\s+)10(.*)"'
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
  run _repeat_until_success_or_timeout 20 _exec_in_container grep -R 'Subject: quota warning' /var/mail/otherdomain.tld/quotauser/new/
  assert_success

  run _repeat_until_success_or_timeout 20 sh -c "docker logs ${CONTAINER_NAME} | grep 'Quota exceeded (mailbox for user is full)'"
  assert_success

  # ensure only the first big message and the warn message are present (other messages are rejected: mailbox is full)
  _run_in_container sh -c 'ls /var/mail/otherdomain.tld/quotauser/new/ | wc -l'
  assert_success
  assert_output "2"

  # Cleanup
  _run_in_container setup email del -y quotauser@otherdomain.tld
  assert_success
}
