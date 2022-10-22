load 'test_helper/common'

TEST_NAME_PREFIX='default relay host:'
CONTAINER_NAME='dms-test-default_relay_host'
RUN_COMMAND=('run' 'docker' 'exec' "${CONTAINER_NAME}")

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  docker run --rm --detach --tty \
    --name "${CONTAINER_NAME}" \
    --hostname mail.my-domain.com \
    --volume "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
    --volume "${PWD}/test/test-files:/tmp/docker-mailserver-test:ro" \
    --env DEFAULT_RELAY_HOST=default.relay.host.invalid:25 \
    --env PERMIT_DOCKER=host \
    "${IMAGE_NAME}"

    wait_for_finished_setup_in_container "${CONTAINER_NAME}"
}

function teardown_file() {
  docker rm -f "${CONTAINER_NAME}"
}

@test "${TEST_NAME_PREFIX} default relay host is added to main.cf" {
  "${RUN_COMMAND[@]}" bash -c 'grep -e "^relayhost =" /etc/postfix/main.cf'
  assert_output 'relayhost = default.relay.host.invalid:25'
}
