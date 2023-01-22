load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Fetchmail] '
CONTAINER1_NAME='dms-test_fetchmail'
CONTAINER2_NAME='dms-test_fetchmail_parallel'

function setup_file() {
  export CONTAINER_NAME

  CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_FETCHMAIL=1
  )
  _init_with_defaults
  mv "${TEST_TMP_CONFIG}/fetchmail/fetchmail.cf" "${TEST_TMP_CONFIG}/fetchmail.cf"
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER2_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_FETCHMAIL=1
    --env FETCHMAIL_PARALLEL=1
  )
  _init_with_defaults
  mv "${TEST_TMP_CONFIG}/fetchmail/fetchmail.cf" "${TEST_TMP_CONFIG}/fetchmail.cf"
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

# ENV `FETCHMAIL=1` runs `setup-stack.sh:_setup_fetchmail()`:
@test "(ENV ENABLE_FETCHMAIL=1) should configure /etc/fetchmailrc with fetchmail.cf contents" {
  export CONTAINER_NAME=${CONTAINER1_NAME}
  # /etc/fetchmailrc was created with general options copied from /etc/fetchmailrc_general:
  _should_have_in_config 'set syslog' /etc/fetchmailrc
  # fetchmail.cf content is appended into /etc/fetchmailrc:
  # NOTE: FQDN value ends with a dot intentionally to avoid misleading DNS response:
  # https://github.com/docker-mailserver/docker-mailserver/pull/1324
  _should_have_in_config 'pop3.third-party.test.' /etc/fetchmailrc
}

# ENV `FETCHMAIL=1` runs `setup-stack.sh:_setup_fetchmail_parallel()`:
# fetchmail.cf should be parsed and split into multiple separate fetchmail configs:
# NOTE: Parallel fetchmail instances are checked in the `process-check-restart.bats` test.
@test "(ENV FETCHMAIL_PARALLEL=1) should create config fetchmail-1.rc" {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  _should_have_in_config     'set syslog'                /etc/fetchmailrc.d/fetchmail-1.rc
  _should_have_in_config     'pop3.third-party.test.'    /etc/fetchmailrc.d/fetchmail-1.rc
  _should_not_have_in_config 'imap.remote-service.test.' /etc/fetchmailrc.d/fetchmail-1.rc
}

@test "(ENV FETCHMAIL_PARALLEL=1) should create config fetchmail-2.rc" {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  _should_have_in_config     'set syslog'                /etc/fetchmailrc.d/fetchmail-2.rc
  _should_have_in_config     'imap.remote-service.test.' /etc/fetchmailrc.d/fetchmail-2.rc
  _should_not_have_in_config 'pop3.third-party.test. '   /etc/fetchmailrc.d/fetchmail-2.rc
}

function _should_have_in_config() {
  local MATCH_CONTENT=$1
  local MATCH_IN_FILE=$2

  _run_in_container grep -F "${MATCH_CONTENT}" "${MATCH_IN_FILE}"
  assert_success
}

function _should_not_have_in_config() {
  local MATCH_CONTENT=$1
  local MATCH_IN_FILE=$2

  _run_in_container grep -F "${MATCH_CONTENT}" "${MATCH_IN_FILE}"
  assert_failure
}
