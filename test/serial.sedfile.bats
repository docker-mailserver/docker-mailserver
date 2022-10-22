load 'test_helper/common'

CONTAINER='sedfile'
TEST_FILE='/tmp/sedfile-test.txt'

# prepare tests
function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . )"

  docker run -d --name "${CONTAINER}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -h mail.my-domain.com "${NAME}"

  wait_for_finished_setup_in_container "${CONTAINER}"
}

function setup() {
  # create test file
  docker exec "${CONTAINER}" bash -c 'echo "foo bar" > "'"${TEST_FILE}"'"'
}

@test "checking sedfile parameter count" {
  run docker exec "${CONTAINER}" sedfile
  assert_failure
  assert_output --partial 'At least three parameters must be given'
}

@test "checking sedfile substitute success" {
  # change 'bar' to 'baz'
  run docker exec "${CONTAINER}" sedfile -i 's|bar|baz|' "${TEST_FILE}"
  assert_success
  assert_output ''

  # file modified?
  run docker exec "${CONTAINER}" cat "${TEST_FILE}"
  assert_success
  assert_output 'foo baz'
}

@test "checking sedfile substitute failure (on first container start)" {
  # delete marker
  run docker exec "${CONTAINER}" rm '/CONTAINER_START'
  assert_success

  # try to change 'baz' to 'something' and fail
  run docker exec "${CONTAINER}" sedfile -i 's|baz|something|' "${TEST_FILE}"
  assert_failure
  assert_output --partial "No difference after call to 'sed' in 'sedfile' (sed -i s|baz|something| /tmp/sedfile-test.txt)"

  # file unchanged?
  run docker exec "${CONTAINER}" cat "${TEST_FILE}"
  assert_success
  assert_output 'foo bar'

  # recreate marker
  run docker exec "${CONTAINER}" touch '/CONTAINER_START'
  assert_success
}

@test "checking sedfile silent failure on substitute (when DMS was restarted)" {
  # try to change 'baz' to 'something' and fail silently
  run docker exec "${CONTAINER}" sedfile -i 's|baz|something|' "${TEST_FILE}"
  assert_success
  assert_output ''

  # file unchanged?
  run docker exec "${CONTAINER}" cat "${TEST_FILE}"
  assert_success
  assert_output 'foo bar'
}

@test "checking sedfile substitude failure (strict)" {
  # try to change 'baz' to 'something' and fail
  run docker exec "${CONTAINER}" sedfile --strict -i 's|baz|something|' "${TEST_FILE}"
  assert_failure
  assert_output --partial "No difference after call to 'sed' in 'sedfile' (sed -i s|baz|something| /tmp/sedfile-test.txt)"

  # file unchanged?
  run docker exec "${CONTAINER}" cat "${TEST_FILE}"
  assert_success
  assert_output 'foo bar'
}

# clean up
function teardown_file() {
  docker rm -f "${CONTAINER}"
}
