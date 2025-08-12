load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_FILE='/tmp/sedfile-test.txt'
BATS_TEST_NAME_PREFIX='[sedfile] '
CONTAINER_NAME='dms-test_sedfile'

# prepare tests
function setup_file() {
  _init_with_defaults
  _common_container_setup
}

function teardown_file() { _default_teardown ; }

function setup() {
  # create test file
  _run_in_container_bash "echo 'foo bar' >'${TEST_FILE}'"
}

@test 'checking parameter count' {
  _run_in_container sedfile
  assert_failure
  assert_output --partial 'At least three parameters must be given'
}

@test 'checking substitute success' {
  # change 'bar' to 'baz'
  _run_in_container sedfile -i 's|bar|baz|' "${TEST_FILE}"
  assert_success
  assert_output ''

  # file modified?
  _run_in_container cat "${TEST_FILE}"
  assert_success
  assert_output 'foo baz'
}

@test 'checking sedfile substitute failure (on first container start)' {
  # delete marker
  _run_in_container rm '/CONTAINER_START'
  assert_success

  # try to change 'baz' to 'something' and fail
  _run_in_container sedfile -i 's|baz|something|' "${TEST_FILE}"
  assert_failure
  assert_output --partial "No difference after call to 'sed' in 'sedfile' (sed -i s|baz|something| /tmp/sedfile-test.txt)"

  # file unchanged?
  _run_in_container cat "${TEST_FILE}"
  assert_success
  assert_output 'foo bar'

  # recreate marker
  _run_in_container touch '/CONTAINER_START'
  assert_success
}

@test 'checking sedfile silent failure on substitute (when DMS was restarted)' {
  # try to change 'baz' to 'something' and fail silently
  _run_in_container sedfile -i 's|baz|something|' "${TEST_FILE}"
  assert_success
  assert_output ''

  # file unchanged?
  _run_in_container cat "${TEST_FILE}"
  assert_success
  assert_output 'foo bar'
}

@test 'checking sedfile substitute failure (strict)' {
  # try to change 'baz' to 'something' and fail
  _run_in_container sedfile --strict -i 's|baz|something|' "${TEST_FILE}"
  assert_failure
  assert_output --partial "No difference after call to 'sed' in 'sedfile' (sed -i s|baz|something| /tmp/sedfile-test.txt)"

  # file unchanged?
  _run_in_container cat "${TEST_FILE}"
  assert_success
  assert_output 'foo bar'
}
