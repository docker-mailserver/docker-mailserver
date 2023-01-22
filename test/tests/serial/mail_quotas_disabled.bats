load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Quotas Disabled] '
CONTAINER_NAME='dms-test_quotas-disabled'

function setup_file() {
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(--env ENABLE_QUOTAS=0)
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test "(Dovecot) quota plugin is disabled" {
  _run_in_container_bash_and_filter_output 'cat /etc/dovecot/conf.d/10-mail.conf'
  refute_output --partial 'quota'

  _run_in_container_bash_and_filter_output 'cat /etc/dovecot/conf.d/20-imap.conf'
  refute_output --partial 'imap_quota'

  _run_in_container_bash "[[ -f /etc/dovecot/conf.d/90-quota.conf ]]"
  assert_failure

  _run_in_container_bash "[[ -f /etc/dovecot/conf.d/90-quota.conf.disab ]]"
  assert_success
}

@test "(Postfix) Dovecot quota absent in postconf" {
  _run_in_container postconf
  assert_success
  refute_output --partial "check_policy_service inet:localhost:65265'"
}
