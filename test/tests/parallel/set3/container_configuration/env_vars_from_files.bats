load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

# Feature (ENV value sourced from file):
# - An ENV with a `__FILE` suffix will read a value from a referenced file path to set the actual ENV (assuming it is empty)
# - Feature implemented at: `variables-stack.sh:__environment_variables_from_files()`
# - Feature PR: https://github.com/docker-mailserver/docker-mailserver/pull/4359

BATS_TEST_NAME_PREFIX='[Configuration] (ENV __FILE support) '
CONTAINER1_NAME='dms-test_env-files_success'
CONTAINER2_NAME='dms-test_env-files_warning'
CONTAINER3_NAME='dms-test_env-files_error'

function setup_file() {
  export CONTAINER_NAME
  export FILEPATH_VALID='/tmp/file-with-value'
  export FILEPATH_INVALID='/path/to/non-existent-file'
  # Each `_init_with_defaults` call updates the `TEST_TMP_CONFIG` location to create a container specific file:
  local FILE_WITH_VALUE

  # ENV is set via file content (valid file path):
  CONTAINER_NAME=${CONTAINER1_NAME}
  _init_with_defaults
  FILE_WITH_VALUE=${TEST_TMP_CONFIG}/test_secret
  echo 1 > "${FILE_WITH_VALUE}"
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_POP3__FILE="${FILEPATH_VALID}"
    -v "${FILE_WITH_VALUE}:${FILEPATH_VALID}"
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # ENV is already set explicitly, a warning should be logged:
  CONTAINER_NAME=${CONTAINER2_NAME}
  _init_with_defaults
  FILE_WITH_VALUE=${TEST_TMP_CONFIG}/test_secret
  echo 1 > "${FILE_WITH_VALUE}"
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_POP3="0"
    --env ENABLE_POP3__FILE="${FILEPATH_VALID}"
    -v "${FILE_WITH_VALUE}:${FILEPATH_VALID}"
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # ENV is not set by file content (invalid file path):
  CONTAINER_NAME=${CONTAINER3_NAME}
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_POP3__FILE="${FILEPATH_INVALID}"
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}" "${CONTAINER3_NAME}"
}

@test "ENV can be set from a file" {
  export CONTAINER_NAME=${CONTAINER1_NAME}

  # /var/log/mail/mail.log is not equivalent to stdout content,
  # Relevant log content only available via docker logs:
  run docker logs "${CONTAINER_NAME}"
  assert_success
  assert_line --partial "Getting secret 'ENABLE_POP3' from '${FILEPATH_VALID}'"

  # Verify ENABLE_POP3 was enabled (disabled by default), by checking this file path is valid:
  _run_in_container [ -f /etc/dovecot/protocols.d/pop3d.protocol ]
  assert_success
}

@test "Non-empty ENV have precedence over their __FILE variant" {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  # /var/log/mail/mail.log is not equivalent to stdout content,
  # Relevant log content only available via docker logs:
  run docker logs "${CONTAINER_NAME}"
  assert_success
  assert_line --partial "ENV value will not be sourced from 'ENABLE_POP3__FILE' since 'ENABLE_POP3' is already set"
}

@test "Referencing a non-existent file logs an error" {
  export CONTAINER_NAME=${CONTAINER3_NAME}

  # /var/log/mail/mail.log is not equivalent to stdout content,
  # Relevant log content only available via docker logs:
  run docker logs "${CONTAINER_NAME}"
  assert_success
  assert_line --partial "File defined for secret 'ENABLE_POP3' with path '${FILEPATH_INVALID}' does not exist"
}
