load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

# upstream default: 10 240 000
# https://www.postfix.org/postconf.5.html#message_size_limit
# > The maximal size in bytes of a message, including envelope information.
# > The value cannot exceed LONG_MAX (typically, a 32-bit or 64-bit signed integer).
# > Note: Be careful when making changes. Excessively small values will result in the loss of non-delivery notifications, when a bounce message size exceeds the local or remote MTA's message size limit.

# upstream default: 51 200 000
# https://www.postfix.org/postconf.5.html#mailbox_size_limit
# > The maximal size of any local(8) individual mailbox or maildir file, or zero (no limit).
# > In fact, this limits the size of any file that is written to upon local delivery, including files written by external commands that are executed by the local(8) delivery agent.
# > The value cannot exceed LONG_MAX (typically, a 32-bit or 64-bit signed integer).
# > This limit must not be smaller than the message size limit.

# upstream default: 51 200 000
# https://www.postfix.org/postconf.5.html#virtual_mailbox_limit
# > The maximal size in bytes of an individual virtual(8) mailbox or maildir file, or zero (no limit).
# > This parameter is specific to the virtual(8) delivery agent.
# > It does not apply when mail is delivered with a different mail delivery program.

BATS_TEST_NAME_PREFIX='[Dovecot Quotas] '
CONTAINER_NAME='dms-test_dovecot-quotas'

function setup_file() {
  _init_with_defaults

  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env ENABLE_QUOTAS=1
    --env POSTFIX_MAILBOX_SIZE_LIMIT=4096000
    --env POSTFIX_MESSAGE_SIZE_LIMIT=2048000
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
  _run_in_container postconf -h mailbox_size_limit
  assert_output 4096000

  # Dovecot mailbox is sized by `virtual_mailbox_size` from Postfix:
  _run_in_container postconf -h virtual_mailbox_limit
  assert_output 4096000

  # Quota support:
  _run_in_container doveconf -h plugin/quota_rule
  # Global default storage limit quota for each mailbox 4 MiB:
  assert_output '*:storage=4M'

  # Sizes are equivalent - Bytes to MiB (rounded):
  run numfmt --to=iec --format '%.0f' 4096000
  assert_output '4M'
}

@test '(ENV POSTFIX_MESSAGE_SIZE_LIMIT) should be configured for both Postfix and Dovecot' {
  _run_in_container postconf -h message_size_limit
  assert_output 2048000

  _run_in_container doveconf -h plugin/quota_max_mail_size
  assert_output '2M'

  # Sizes are equivalent - Bytes to MiB (rounded):
  run numfmt --to=iec --format '%.0f' 2048000
  assert_output '2M'
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
  # sed -nE 's/.*STORAGE.*Limit=([0-9]+).*/\1/p' | numfmt --from-unit=1024 --to=iec --format '%.0f'
  local CMD_GET_QUOTA="doveadm -f flow quota get -u 'user1@localhost.localdomain'"

  # 4M == 4096 kiB (numfmt --to-unit=1024 --from=iec 4M)
  _run_in_container_bash "${CMD_GET_QUOTA}"
  assert_line --partial 'Type=STORAGE Value=0 Limit=4096'

  # Setting a new limit for the user:
  _run_in_container setup quota set 'user1@localhost.localdomain' 50M
  assert_success
  # 50M (50 * 1024^2) == 51200 kiB (numfmt --to-unit=1024 --from=iec 52428800)
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash "${CMD_GET_QUOTA} | grep -o 'Type=STORAGE Value=0 Limit=51200'"
  assert_success

  # Deleting quota resets it to default global quota limit (`plugin/quota_rule`):
  _run_in_container setup quota del 'user1@localhost.localdomain'
  assert_success
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash "${CMD_GET_QUOTA} | grep -o 'Type=STORAGE Value=0 Limit=4096'"
  assert_success
}

@test 'should receive a warning mail from Dovecot when quota is exceeded' {
  # skip 'disabled as it fails randomly: https://github.com/docker-mailserver/docker-mailserver/pull/2511'

  # Prepare
  _add_mail_account_then_wait_until_ready 'quotauser@otherdomain.tld'

  # Actual tests
  _run_in_container setup quota set quotauser@otherdomain.tld 10k
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash "doveadm -f flow quota get -u 'quotauser@otherdomain.tld' | grep -o 'Type=STORAGE Value=0 Limit=10'"
  assert_success

  # dovecot and postfix has been restarted
  _wait_for_service postfix
  _wait_for_service dovecot
  sleep 10

  # send some big emails
  _send_email --to 'quotauser@otherdomain.tld' --data 'quota-exceeded.txt'
  _send_email --to 'quotauser@otherdomain.tld' --data 'quota-exceeded.txt'
  _send_email --to 'quotauser@otherdomain.tld' --data 'quota-exceeded.txt'
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
