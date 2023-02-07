load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Amavis + SA] '
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

@test 'SpamAssassin integration should be active' {
  # give Amavis just a bit of time to print out its full debug log
  run _repeat_in_container_until_success_or_timeout 5 "${CONTAINER_NAME}" grep 'ANTI-SPAM-SA' /var/log/mail/mail.log
  assert_success
  assert_output --partial 'loaded'
  refute_output --partial 'NOT loaded'
}

@test 'SA ENV should update Amavis config' {
  local AMAVIS_DEFAULTS_FILE='/etc/amavis/conf.d/20-debian_defaults'
  _run_in_container grep '\$sa_tag_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial '= 2.0'

  _run_in_container grep '\$sa_tag2_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial '= 6.31'

  _run_in_container grep '\$sa_kill_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial '= 6.31'

  _run_in_container grep '\$sa_spam_subject_tag' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial "= '***SPAM*** ';"
}
