load 'test_helper/common'

TEST_NAME_PREFIX='Dovecot protocols:'
CONTAINER_NAME_IPV4='dms-test-dovecot_protocols_ipv4'
CONTAINER_NAME_IPV6='dms-test-dovecot_protocols_ipv6'
CONTAINER_NAME_ALL='dms-test-dovecot_protocols_all'

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME_IPV4}")

  docker run --rm --detach --tty \
    --name "${CONTAINER_NAME_ALL}" \
    --hostname mail.my-domain.com \
    --volume "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
    --env DOVECOT_INET_PROTOCOLS= \
    "${IMAGE_NAME}"

  docker run --rm --detach --tty \
    --name "${CONTAINER_NAME_IPV4}" \
    --hostname mail.my-domain.com \
    --volume "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
    --env DOVECOT_INET_PROTOCOLS=ipv4 \
    "${IMAGE_NAME}"

  docker run --rm --detach --tty \
    --name "${CONTAINER_NAME_IPV6}" \
    --hostname mail.my-domain.com \
    --volume "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
    --env DOVECOT_INET_PROTOCOLS=ipv6 \
    "${IMAGE_NAME}"
}

@test "${TEST_NAME_PREFIX} dual-stack IP configuration" {
  wait_for_finished_setup_in_container "${CONTAINER_NAME_ALL}"
  run docker exec "${CONTAINER_NAME_ALL}" grep '^#listen = \*, ::' /etc/dovecot/dovecot.conf
  assert_success
  assert_output '#listen = *, ::'
}

@test "${TEST_NAME_PREFIX} IPv4 configuration" {
  wait_for_finished_setup_in_container "${CONTAINER_NAME_IPV4}"
  run docker exec "${CONTAINER_NAME_IPV4}" grep '^listen = \*$' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = *'
}

@test "${TEST_NAME_PREFIX} IPv6 configuration" {
  wait_for_finished_setup_in_container "${CONTAINER_NAME_IPV6}"
  run docker exec "${CONTAINER_NAME_IPV6}" grep '^listen = \[::\]$' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = [::]'
}

function teardown_file {
  docker rm -f "${CONTAINER_NAME_ALL}" "${CONTAINER_NAME_IPV4}" "${CONTAINER_NAME_IPV6}"
}
