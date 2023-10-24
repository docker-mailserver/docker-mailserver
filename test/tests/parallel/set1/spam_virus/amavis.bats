load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Amavis + SA] '
CONTAINER1_NAME='dms-test_amavis_enabled'
CONTAINER2_NAME='dms-test_amavis_disabled'

function setup_file() {
  export CONTAINER_NAME

  CONTAINER_NAME=${CONTAINER1_NAME}
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env AMAVIS_LOGLEVEL=2
    --env ENABLE_SPAMASSASSIN=1
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER2_NAME}
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=0
    --env ENABLE_SPAMASSASSIN=0
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

@test '(Amavis enabled) configuration should be correct' {
  export CONTAINER_NAME=${CONTAINER1_NAME}

  _run_in_container postconf -h content_filter
  assert_success
  assert_line 'smtp-amavis:[127.0.0.1]:10024'
  _run_in_container grep 'smtp-amavis' /etc/postfix/master.cf
  assert_success
  _run_in_container grep -F '127.0.0.1:10025' /etc/postfix/master.cf
  assert_success

  _run_in_container_bash '[[ -f /etc/cron.d/amavisd-new.disabled ]]'
  assert_failure
  _run_in_container_bash '[[ -f /etc/cron.d/amavisd-new ]]'
  assert_success
}

@test '(Amavis enabled) SA integration should be active' {
  export CONTAINER_NAME=${CONTAINER1_NAME}

  # give Amavis just a bit of time to print out its full debug log
  run _repeat_in_container_until_success_or_timeout 5 "${CONTAINER_NAME}" grep 'ANTI-SPAM-SA' /var/log/mail/mail.log
  assert_success
  assert_output --partial 'loaded'
  refute_output --partial 'NOT loaded'
}

@test '(Amavis enabled) SA ENV should update Amavis config' {
  export CONTAINER_NAME=${CONTAINER1_NAME}

  local AMAVIS_DEFAULTS_FILE='/etc/amavis/conf.d/20-debian_defaults'
  # shellcheck disable=SC2016
  _run_in_container grep '\$sa_tag_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial '= 2.0'

  # shellcheck disable=SC2016
  _run_in_container grep '\$sa_tag2_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial '= 6.31'

  # shellcheck disable=SC2016
  _run_in_container grep '\$sa_kill_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial '= 10.0'

  # shellcheck disable=SC2016
  _run_in_container grep '\$sa_spam_subject_tag' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial "= '***SPAM*** ';"
}

@test '(Amavis disabled) configuration should be correct' {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  _run_in_container postconf -h content_filter
  assert_success
  refute_output --partial 'smtp-amavis:[127.0.0.1]:10024'
  _run_in_container grep 'smtp-amavis' /etc/postfix/master.cf
  assert_failure
  _run_in_container grep -F '127.0.0.1:10025' /etc/postfix/master.cf
  assert_failure

  _run_in_container_bash '[[ -f /etc/cron.d/amavisd-new.disabled ]]'
  assert_success
  _run_in_container_bash '[[ -f /etc/cron.d/amavisd-new ]]'
  assert_failure
}
