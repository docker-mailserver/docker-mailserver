load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Amavis + SA] '
CONTAINER1_NAME='dms-test_amavis-enabled-default'
CONTAINER2_NAME='dms-test_amavis-enabled-custom'
CONTAINER3_NAME='dms-test_amavis-disabled'

function setup_file() {
  export CONTAINER_NAME

  CONTAINER_NAME=${CONTAINER1_NAME}
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_SPAMASSASSIN=1
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER2_NAME}
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env AMAVIS_LOGLEVEL=2
    --env ENABLE_SPAMASSASSIN=1
    --env SA_TAG=-5.0
    --env SA_TAG2=2.0
    --env SA_KILL=3.0
    --env SPAM_SUBJECT='***SPAM*** '
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER3_NAME}
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=0
    --env ENABLE_SPAMASSASSIN=0
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}" "${CONTAINER3_NAME}"
}

@test '(Amavis enabled - defaults) default Amavis config is correct' {
  export CONTAINER_NAME=${CONTAINER1_NAME}
  local AMAVIS_DEFAULTS_FILE='/etc/amavis/conf.d/20-debian_defaults'

  _run_in_container grep 'sa_tag_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  assert_output --partial 'sa_tag_level_deflt = 2.0;'

  _run_in_container grep 'sa_tag2_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  # shellcheck disable=SC2016
  assert_output --partial '$sa_tag2_level_deflt = 6.31;'

  _run_in_container grep 'sa_kill_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  # shellcheck disable=SC2016
  assert_output --partial '$sa_kill_level_deflt = 10.0;'

  # This feature is handled by our SPAM_SUBJECT ENV through a sieve script instead.
  # Thus the feature here should always be disabled via the 'undef' value.
  _run_in_container grep 'sa_spam_subject_tag' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  # shellcheck disable=SC2016
  assert_output --partial '$sa_spam_subject_tag = undef;'
}

@test '(Amavis enabled - custom) configuration should be correct' {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  _run_in_container postconf -h content_filter
  assert_success
  assert_line 'smtp-amavis:[127.0.0.1]:10024'
  _run_in_container grep 'smtp-amavis' /etc/postfix/master.cf
  assert_success
  _run_in_container grep -F '127.0.0.1:10025' /etc/postfix/master.cf
  assert_success

  _file_does_not_exist_in_container /etc/cron.d/amavisd-new.disabled
  _file_exists_in_container /etc/cron.d/amavisd-new
}

@test '(Amavis enabled - custom) SA integration should be active' {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  # give Amavis just a bit of time to print out its full debug log
  run _repeat_in_container_until_success_or_timeout 20 "${CONTAINER_NAME}" grep 'SpamControl: init_pre_fork on SpamAssassin done' /var/log/mail/mail.log
  assert_success
}

@test '(Amavis enabled - custom) ENV should update Amavis config' {
  export CONTAINER_NAME=${CONTAINER2_NAME}
  local AMAVIS_DEFAULTS_FILE='/etc/amavis/conf.d/20-debian_defaults'

  _run_in_container grep 'sa_tag_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  # shellcheck disable=SC2016
  assert_output --partial '$sa_tag_level_deflt = -5.0;'

  _run_in_container grep 'sa_tag2_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  # shellcheck disable=SC2016
  assert_output --partial '$sa_tag2_level_deflt = 2.0;'

  _run_in_container grep 'sa_kill_level_deflt' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  # shellcheck disable=SC2016
  assert_output --partial '$sa_kill_level_deflt = 3.0;'

  # This feature is handled by our SPAM_SUBJECT ENV through a sieve script instead.
  # Thus the feature here should always be disabled via the 'undef' value.
  _run_in_container grep 'sa_spam_subject_tag' "${AMAVIS_DEFAULTS_FILE}"
  assert_success
  # shellcheck disable=SC2016
  assert_output --partial '$sa_spam_subject_tag = undef;'
}

@test '(Amavis disabled) configuration should be correct' {
  export CONTAINER_NAME=${CONTAINER3_NAME}

  _run_in_container postconf -h content_filter
  assert_success
  refute_output --partial 'smtp-amavis:[127.0.0.1]:10024'
  _run_in_container grep 'smtp-amavis' /etc/postfix/master.cf
  assert_failure
  _run_in_container grep -F '127.0.0.1:10025' /etc/postfix/master.cf
  assert_failure

  _file_exists_in_container /etc/cron.d/amavisd-new.disabled
  _file_does_not_exist_in_container /etc/cron.d/amavisd-new
}
