load 'test_helper/common'

# ? global variable initialization
# ?   currenlty here for transition from $NAME
IMAGE_NAME=${NAME:-mailserver-testing:ci}
# ?   to identify the test easily
TEST_NAME_PREFIX='checking template: '
# ?   must be unique
CONTAINER_NAME='dms-test-template'
# ?   use this to execute someting inside the container
RUN_COMMAND=('run' 'docker' 'exec' "${CONTAINER_NAME}")

# ? test setup

function setup_file() {
  # ? optional setup before container is started

  # ? start of the container
  # ?   PRIVATE_CONFIG must be set properly
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  # ?   the run command should look like this, and only the `--env`
  # ?   should differe from test file to test file; if not needed,
  # ?   disable AV / anti-spam software
  docker run --rm --detach --tty \
    --name "${CONTAINER_NAME}" \
    --hostname mail.my-domain.com \
    --volume "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
    --env ENABLE_AMAVIS=0 \
    --env ENABLE_CLAMAV=0 \
    --env ENABLE_UPDATE_CHECK=0 \
    --env ENABLE_SPAMASSASSIN=0 \
    --env ENABLE_FAIL2BAN=0 \
    --env LOG_LEVEL=debug \
    "${IMAGE_NAME}"

  # ?   wait for the container to be ready
  wait_for_finished_setup_in_container "${CONTAINER_NAME}"

  # ? optional setup after the container is started
}

# ? test finalization

function teardown_file() {
  docker rm -f "${CONTAINER_NAME}"
}

# ? actual unit tests

@test "${TEST_NAME_PREFIX}default check" {
  "${RUN_COMMAND[@]}" bash -c "true"
  assert_success
}
