load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Rspamd] (Valkey migration) '
CONTAINER_NAME='dms-test_rspamd-valkey-migration'

function setup_file() {
  _init_with_defaults

  # A Redis 7.4+ dump (RDB format 12) that Valkey cannot load
  local MAIL_STATE="${TEST_TMP_CONFIG}/mail-state"
  mkdir -p "${MAIL_STATE}/lib-redis"
  printf 'REDIS0012' >"${MAIL_STATE}/lib-redis/dms-dump.rdb"

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_RSPAMD=1
    --env ENABLE_OPENDKIM=0
    --env ENABLE_OPENDMARC=0
    --env ENABLE_POLICYD_SPF=0
    --volume "${MAIL_STATE}:/var/mail-state"
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_service rspamd-valkey
}

function teardown_file() { _default_teardown ; }

@test 'incompatible Redis state is kept and Valkey starts empty' {
  _run_in_container valkey-cli ping
  assert_success
  assert_output 'PONG'

  _run_in_container test -f /var/mail-state/lib-redis/dms-dump.rdb
  assert_success

  run docker logs "${CONTAINER_NAME}"
  assert_output --partial "uses RDB format 'REDIS0012' which Valkey cannot load"
}
