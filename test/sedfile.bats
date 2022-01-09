load 'test_helper/common'

# prepare tests
function setup_file() {
  export CONTAINER_START FILE SEDFILE
  FILE=$(mktemp /tmp/sedfile-test.XXX)
  SEDFILE="/tmp/sedfile"

  # workaround, /CONTAINER_START cannot be used (permission denied)
  CONTAINER_START="/tmp/CONTAINER_START"
  cp -a "target/bin/sedfile" "${SEDFILE}"
  sed -i "s|/CONTAINER_START|${CONTAINER_START}|" "${SEDFILE}"

  # create test file
  echo 'foo bar' > "${FILE}"
}

@test "checking sedfile parameter count" {
  run ${SEDFILE}
  assert_failure
  assert_output --partial 'Error:  At least, three parameters must be given.'
}

@test "checking sedfile substitute success" {
  # change 'bar' to 'baz'
  run ${SEDFILE} -i 's|bar|baz|' "${FILE}"
  assert_success
  assert_output ""

  # file modified?
  run test "$(< "${FILE}")" == 'foo baz'
  assert_success
}

@test "checking sedfile substitute failure" {
  run ${SEDFILE} -i 's|bar|baz|' "${FILE}"
  assert_failure
  assert_output --partial "Error: sed -i s|bar|baz| /tmp/sedfile-test."

  # file unchanged?
  run test "$(< "${FILE}")" == 'foo baz'
  assert_success
}

@test "checking sedfile silent failure on substitute" {
  # create marker to simulate a container restart
  date > "${CONTAINER_START}"

  run ${SEDFILE} -i 's|bar|baz|' "${FILE}"
  assert_success
  assert_output ""

  # file unchanged?
  run test "$(< "${FILE}")" == 'foo baz'
  assert_success
}

@test "checking sedfile substitude failure (strict)" {
  run ${SEDFILE} --strict -i 's|bar|baz|' "${FILE}"
  assert_failure
  assert_output --partial "Error: sed -i s|bar|baz| /tmp/sedfile-test."

  # file unchanged?
  run test "$(< "${FILE}")" == 'foo baz'
  assert_success
}

# clean up
function teardown_file() {
  rm -f "${CONTAINER_START}" "${FILE}" "${SEDFILE}"
}
