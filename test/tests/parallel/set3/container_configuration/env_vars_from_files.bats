load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

export CONTAINER1_NAME='dms-test_env-files_success'
export CONTAINER2_NAME='dms-test_env-files_warning'
export CONTAINER3_NAME='dms-test_env-files_error'

setup_file() {
  export TEST__FILE
  TEST__FILE=$(mktemp)
  export NON_EXISTENT__FILE="/tmp/non_existent_secret"

  echo 1 > "${TEST__FILE}"
}

teardown_file() {
  rm -f "${TEST__FILE}"
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}" "${CONTAINER3_NAME}"
}

@test "Environment variables are loaded from files" {
  export CONTAINER_NAME="${CONTAINER1_NAME}"
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_POP3__FILE="${TEST__FILE}"
    -v "${TEST__FILE}:${TEST__FILE}"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  run docker logs "${CONTAINER_NAME}"

  assert_success
  assert_line --partial "Getting secret ENABLE_POP3 from ${TEST__FILE}"
  _exec_in_container [ -f /etc/dovecot/protocols.d/pop3d.protocol ]
  assert_success
}

@test "Existing environment variables take precedence over __FILE variants" {
  export CONTAINER_NAME="${CONTAINER2_NAME}"
  local CUSTOM_SETUP_ARGUMENTS=(
    --env TEST="manual-secret"
    --env TEST__FILE="${TEST__FILE}"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  run docker logs "${CONTAINER_NAME}"

  assert_success
  assert_line --partial "Ignoring TEST since TEST__FILE is also set"
}

@test "Non-existent file triggers an error" {
  export CONTAINER_NAME="${CONTAINER3_NAME}"
  local CUSTOM_SETUP_ARGUMENTS=(
    --env TEST__FILE="${NON_EXISTENT__FILE}"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  run docker logs "${CONTAINER_NAME}"

  assert_success
  assert_line --partial "File ${NON_EXISTENT__FILE} does not exist"
}
