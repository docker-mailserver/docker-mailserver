load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[OAuth2] '
CONTAINER1_NAME='dms-test_oauth2'
CONTAINER2_NAME='dms-test_oauth2_provider'

function setup_file() {
  export DMS_TEST_NETWORK='test-network-oauth2'
  export DMS_DOMAIN='example.test'
  export FQDN_MAIL="mail.${DMS_DOMAIN}"
  export FQDN_OAUTH2="oauth2.${DMS_DOMAIN}"

  # Link the test containers to separate network:
  # NOTE: If the network already exists, test will fail to start.
  docker network create "${DMS_TEST_NETWORK}"

  # Setup local oauth2 provider service:
  docker run --rm -d --name "${CONTAINER2_NAME}" \
    --hostname "${FQDN_OAUTH2}" \
    --network "${DMS_TEST_NETWORK}" \
    --volume "${REPOSITORY_ROOT}/test/config/oauth2/:/app/" \
    docker.io/library/python:latest \
    python /app/provider.py

  _run_until_success_or_timeout 20 sh -c "docker logs ${CONTAINER2_NAME} 2>&1 | grep 'Starting server'"

  #
  # Setup DMS container
  #

  # Add OAUTH2 configuration so that Dovecot can reach out to our mock provider (CONTAINER2)
  local ENV_OAUTH2_CONFIG=(
    --env ENABLE_OAUTH2=1
    --env OAUTH2_INTROSPECTION_URL=http://oauth2.example.test/userinfo/
  )

  export CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    "${ENV_OAUTH2_CONFIG[@]}"

    --hostname "${FQDN_MAIL}"
    --network "${DMS_TEST_NETWORK}"
  )

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_tcp_port_in_container 143

  # Set default implicit container fallback for helpers:
  export CONTAINER_NAME=${CONTAINER1_NAME}
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
  docker network rm "${DMS_TEST_NETWORK}"
}


@test "oauth2: imap connect and authentication works" {
  # An initial connection needs to be made first, otherwise the auth attempt fails
  _run_in_container_bash 'nc -vz 0.0.0.0 143'

  _nc_wrapper 'auth/imap-oauth2-auth.txt' '-w 1 0.0.0.0 143'
  assert_output --partial 'Examine completed'
}
