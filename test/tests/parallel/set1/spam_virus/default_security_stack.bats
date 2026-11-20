load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

# Docs: https://docker-mailserver.github.io/docker-mailserver/edge/config/security/rspamd/
# Regression tests for https://github.com/docker-mailserver/docker-mailserver/issues/4364

BATS_TEST_NAME_PREFIX='[Default security stack] '

function teardown() { _default_teardown ; }

@test "should run Rspamd and none of the legacy services by default" {
  export CONTAINER_NAME='dms-test_default-security-stack_defaults'

  # The test helpers pin `ENABLE_AMAVIS` and `ENABLE_RSPAMD`, an empty value makes DMS apply its default again:
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=
    --env ENABLE_RSPAMD=
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_service rspamd-valkey
  _wait_for_service rspamd
  _wait_for_service postfix

  local SERVICE
  for SERVICE in amavis opendkim opendmarc; do
    _run_in_container /usr/bin/supervisorctl status "${SERVICE}"
    refute_output --partial 'RUNNING'
  done

  _run_in_container postconf -h smtpd_milters
  assert_success
  # shellcheck disable=SC2016
  assert_output '$rspamd_milter'

  _run_in_container postconf -h smtpd_recipient_restrictions
  assert_success
  refute_output --partial 'policyd-spf'
}

@test "should refuse to start with OpenDKIM keys when ENABLE_OPENDKIM is not set" {
  export CONTAINER_NAME='dms-test_default-security-stack_opendkim-keys'

  _init_with_defaults
  mv "${TEST_TMP_CONFIG}/example-opendkim/" "${TEST_TMP_CONFIG}/opendkim/"
  _common_container_create
  _common_container_start

  _repeat_until_success_or_timeout 60 bash -c "docker logs ${CONTAINER_NAME} 2>&1 | grep -F 'OpenDKIM is disabled by default since DMS v18'"
  _repeat_until_success_or_timeout 60 bash -c "[[ \$(docker inspect -f '{{.State.Running}}' ${CONTAINER_NAME}) == 'false' ]]"
}

@test "should start with OpenDKIM keys when ENABLE_OPENDKIM is set explicitly" {
  export CONTAINER_NAME='dms-test_default-security-stack_opendkim-keys-confirmed'

  local CUSTOM_SETUP_ARGUMENTS=(--env ENABLE_OPENDKIM=0)
  _init_with_defaults
  mv "${TEST_TMP_CONFIG}/example-opendkim/" "${TEST_TMP_CONFIG}/opendkim/"
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  run docker logs "${CONTAINER_NAME}"
  refute_output --partial 'OpenDKIM is disabled by default since DMS v18'
}
