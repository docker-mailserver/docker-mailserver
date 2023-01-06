load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

TEST_NAME_PREFIX='Amavis:'
CONTAINER_NAME='dms-test_amavis'

function setup_file() {
  init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env AMAVIS_LOGLEVEL=2
    --env ENABLE_SPAMASSASSIN=1
  )

  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test "${TEST_NAME_PREFIX} Amavis integration should be active" {
  _run_in_container grep 'ANTI-SPAM-SA' /var/log/mail/mail.log
  assert_output --partial 'loaded'
  refute_output --partial 'NOT loaded'
}
