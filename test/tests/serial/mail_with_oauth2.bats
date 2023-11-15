load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[OAuth2] '
CONTAINER1_NAME='dms-test_oauth2'
CONTAINER2_NAME='dms-test_oauth2_provider'

function setup_file() {
  export DMS_TEST_NETWORK='test-network-oauth2'
  export DMS_DOMAIN='example.test'
  export FQDN_MAIL="mail.${DMS_DOMAIN}"
  export FQDN_OAUTH2="provider.${DMS_DOMAIN}"

  # Link the test containers to separate network:
  # NOTE: If the network already exists, test will fail to start.
  docker network create "${DMS_TEST_NETWORK}"

  # Setup local oauth2 provider service:
  docker run --rm -d --name "${CONTAINER2_NAME}" \
    --hostname "${FQDN_OAUTH2}" \
    --network "${DMS_TEST_NETWORK}" \
    --user "$(id -u):$(id -g)" \
    --volume "${REPOSITORY_ROOT}/test/config/oauth2/:/app/" \
    --expose 80 \
    docker.io/library/python:latest \
    python /app/provider.py

  _run_until_success_or_timeout 20 sh -c "docker logs ${CONTAINER2_NAME} 2>&1 | grep 'Starting server'"

  #
  # Setup DMS container
  #

  local ENV_OAUTH2_CONFIG=(
    --env ENABLE_OAUTH2=1
    --env OAUTH2_CLIENT_ID=mailserver
    --env OAUTH2_CLIENT_SECRET=ah_yes___secret
    --env OAUTH2_INTROSPECTION_URL=http://provider.example.test/
  )

  local ENV_SUPPORT=(
    --env PERMIT_DOCKER=container
  )

  export CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    "${ENV_OAUTH2_CONFIG[@]}"
    "${ENV_SUPPORT[@]}"

    --hostname "${FQDN_MAIL}"
    --network "${DMS_TEST_NETWORK}"
  )

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  # Set default implicit container fallback for helpers:
  export CONTAINER_NAME=${CONTAINER1_NAME}
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
  docker network rm "${DMS_TEST_NETWORK}"
}

# Could optionally call `_default_teardown` in test-cases that have specific containers.
# This will otherwise handle it implicitly which is helpful when the test-case hits a failure,
# As failure will bail early missing teardown, which then prevents network cleanup. This way is safer:
function teardown() {
  if [[ ${CONTAINER_NAME} != "${CONTAINER1_NAME}" ]] \
  && [[ ${CONTAINER_NAME} != "${CONTAINER2_NAME}" ]]
  then
    _default_teardown
  fi
}

@test "oauth2: imap connect and authentication works" {
  _run_in_container_bash 'nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-oauth2-auth.txt'
  assert_success
}
