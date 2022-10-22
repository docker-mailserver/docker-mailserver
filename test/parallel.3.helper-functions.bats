load 'test_helper/common'

IMAGE_NAME=${NAME:-mailserver-testing:ci}
TEST_NAME_PREFIX='helper functions: '
CONTAINER_NAME='dms-test-helper_functions'

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  docker run --detach --tty \
    --name "${CONTAINER_NAME}" \
    --hostname mail.my-domain.com \
    --volume "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    --volume "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    --cap-add=NET_ADMIN \
    --env ENABLE_AMAVIS=0 \
    --env ENABLE_CLAMAV=0 \
    --env ENABLE_UPDATE_CHECK=0 \
    --env ENABLE_SPAMASSASSIN=0 \
    --env ENABLE_FAIL2BAN=0 \
    --env ENABLE_FETCHMAIL=1 \
    "${IMAGE_NAME}"

  wait_for_finished_setup_in_container "${CONTAINER_NAME}"
}

function teardown_file() {
    docker rm -f "${CONTAINER_NAME}"
}

@test "${TEST_NAME_PREFIX}function _sanitize_ipv4_to_subnet_cidr" {
  run docker exec "${CONTAINER_NAME}" bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 255.255.255.255/0"
  assert_output "0.0.0.0/0"

  run docker exec "${CONTAINER_NAME}" bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 192.168.255.14/20"
  assert_output "192.168.240.0/20"

  run docker exec "${CONTAINER_NAME}" bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 192.168.255.14/32"
  assert_output "192.168.255.14/32"
}
