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
  # Neither the quota plugins nor the quota services are part of the effective Dovecot config:
  _run_in_container doveconf -n
  assert_success
  refute_output --partial 'quota'

  _file_does_not_exist_in_container /etc/dovecot/conf.d/quota.conf
}

@test "(Postfix) Dovecot quota absent in postconf" {
  _run_in_container postconf
  assert_success
  refute_output --partial "check_policy_service inet:localhost:65265'"
}
