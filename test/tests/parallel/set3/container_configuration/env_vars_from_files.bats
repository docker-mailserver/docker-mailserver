load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

export CONTAINER1_NAME='dms-test_env-files_success'
export CONTAINER2_NAME='dms-test_env-files_warning'
export CONTAINER3_NAME='dms-test_env-files_error'

setup_file() {
  export CONTAINER_NAME
  export TEST__FILE
  export TEST__FILE_SUCCESS
  export NON_EXISTENT__FILE

  CONTAINER_NAME=${CONTAINER1_NAME}
  _init_with_defaults
  TEST__FILE=${TEST_TMP_CONFIG}/test_secret
  echo 1 > "${TEST__FILE}"
  TEST__FILE_SUCCESS=${TEST__FILE}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_POP3__FILE="${TEST__FILE}"
    -v "${TEST__FILE}:${TEST__FILE}"
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER2_NAME}
  _init_with_defaults
  TEST__FILE=${TEST_TMP_CONFIG}/test_secret
  local CUSTOM_SETUP_ARGUMENTS=(
    --env TEST="manual-secret"
    --env TEST__FILE="${TEST__FILE}"
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER3_NAME}
  _init_with_defaults
  NON_EXISTENT__FILE="/tmp/non_existent_secret"
  local CUSTOM_SETUP_ARGUMENTS=(
    --env TEST__FILE="${NON_EXISTENT__FILE}"
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

teardown_file() {
  rm -f "${TEST__FILE_SUCCESS}" "${TEST__FILE_WARNING}"
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}" "${CONTAINER3_NAME}"
}

@test "Environment variables are loaded from files" {
  run docker logs "${CONTAINER1_NAME}"
  assert_success
  assert_line --partial "Getting secret ENABLE_POP3 from ${TEST__FILE_SUCCESS}"
  _exec_in_container_explicit "${CONTAINER1_NAME}" [ -f /etc/dovecot/protocols.d/pop3d.protocol ]
  assert_success
}

@test "Existing environment variables take precedence over __FILE variants" {
  run docker logs "${CONTAINER2_NAME}"
  assert_success
  assert_line --partial "Ignoring TEST since TEST__FILE is also set"
}

@test "Non-existent file triggers an error" {
  run docker logs "${CONTAINER3_NAME}"
  assert_success
  assert_line --partial "File ${NON_EXISTENT__FILE} does not exist"
}
