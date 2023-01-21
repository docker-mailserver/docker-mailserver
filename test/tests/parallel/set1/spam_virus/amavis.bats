load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Amavis] '
CONTAINER_NAME='dms-test_amavis'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env AMAVIS_LOGLEVEL=2
    --env ENABLE_SPAMASSASSIN=1
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test "SpamAssassin integration should be active" {
  # give Amavis just a bit of time to print out its full debug log
  run _repeat_in_container_until_success_or_timeout 5 "${CONTAINER_NAME}" grep 'ANTI-SPAM-SA' /var/log/mail/mail.log
  assert_success
  assert_output --partial 'loaded'
  refute_output --partial 'NOT loaded'
}
