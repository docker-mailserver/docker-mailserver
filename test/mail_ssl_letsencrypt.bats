load 'test_helper/common'

# Applies per test:
function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

# Applies to all tests:
function setup_file() {
  init_with_defaults
}

# Not used
# function teardown_file() {
# }

# this test must come first to reliably identify when to run setup_file
@test "first" {
  skip 'Starting testing of letsencrypt SSL'
}

@test "ssl(letsencrypt): Should default to HOSTNAME (mail.my-domain.com)" {
  local TARGET_DOMAIN='mail.my-domain.com'

  local TEST_DOCKER_ARGS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env SSL_TYPE='letsencrypt'
  )

  common_container_setup TEST_DOCKER_ARGS

  #test hostname has certificate files
  _should_have_valid_config "${TARGET_DOMAIN}" 'privkey.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls

  docker rm -f "${TEST_NAME}"
}

@test "ssl(letsencrypt): Should fallback to DOMAINNAME (my-domain.com)" {
  local TARGET_DOMAIN='my-domain.com'

  local TEST_DOCKER_ARGS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env SSL_TYPE='letsencrypt'
  )

  common_container_setup TEST_DOCKER_ARGS

  #test domain has certificate files
  _should_have_valid_config "${TARGET_DOMAIN}" 'key.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls

  docker rm -f "${TEST_NAME}"
}

#
# acme.json updates
#

@test "ssl(letsencrypt): Traefik 'acme.json' (*.example.com)" {
  VOLUME_LETSENCRYPT="${TEST_TMP_CONFIG}/acme.json:/etc/letsencrypt/acme.json:ro"
  # Copy will mounted as volume and overwritten with another `acme.json` during testing:
  cp "${TEST_TMP_CONFIG}/letsencrypt/acme.json" "${TEST_TMP_CONFIG}/acme.json"

  local TEST_DOCKER_ARGS=(
    --volume "${VOLUME_LETSENCRYPT}"
    --env SSL_TYPE='letsencrypt'
    --env SSL_DOMAIN='*.example.com'
    --env DMS_DEBUG=1
  )

  common_container_setup TEST_DOCKER_ARGS

  # "checking changedetector: server is ready"
  run docker exec "${TEST_NAME}" /bin/bash -c "ps aux | grep '/bin/bash /usr/local/bin/check-for-changes.sh'"
  assert_success

  # "can extract certs from acme.json"
  local CONTAINER_BASE_PATH='/etc/letsencrypt/live/mail.my-domain.com'
  local LOCAL_BASE_PATH
  LOCAL_BASE_PATH="${TEST_TMP_CONFIG}/letsencrypt/mail.my-domain.com"

  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/key.pem" "${LOCAL_BASE_PATH}/privkey.pem"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/fullchain.pem" "${LOCAL_BASE_PATH}/fullchain.pem"

  # "can detect changes"
  cp "${TEST_TMP_CONFIG}/letsencrypt/acme-changed.json" "${TEST_TMP_CONFIG}/acme.json"
  sleep 11

  run docker exec "${TEST_NAME}" /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"
  assert_output --partial "Change detected"

  LOCAL_BASE_PATH="${TEST_TMP_CONFIG}/letsencrypt/changed"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/key.pem" "${LOCAL_BASE_PATH}/key.pem"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/fullchain.pem" "${LOCAL_BASE_PATH}/fullchain.pem"

  docker rm -f "${TEST_NAME}"
}


 # this test is only there to reliably mark the end for the teardown_file
@test "last" {
  skip 'Finished testing of letsencrypt SSL'
}


#
# Test Methods
#


function _should_have_valid_config() {
  local EXPECTED_FQDN=${1}
  local LE_KEY_PATH="/etc/letsencrypt/live/${EXPECTED_FQDN}/${2}"
  local LE_CERT_PATH="/etc/letsencrypt/live/${EXPECTED_FQDN}/${3}"

  _has_matching_line "postconf | grep 'smtpd_tls_chain_files = ${LE_KEY_PATH} ${LE_CERT_PATH}'"
  _has_matching_line "doveconf | grep 'ssl_cert = <${LE_CERT_PATH}'"
  # `-P` is required to prevent redacting secrets
  _has_matching_line "doveconf -P | grep 'ssl_key = <${LE_KEY_PATH}'"
}

function _has_matching_line() {
  run docker exec "${TEST_NAME}" /bin/sh -c "${1} | wc -l"
  assert_success
  assert_output 1
}

function _should_succesfully_negotiate_tls() {
  run docker exec "${TEST_NAME}" /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
  run docker exec "${TEST_NAME}" /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:465 -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

function _should_be_equal_in_content() {
  local CONTAINER_PATH=${1}
  local LOCAL_PATH=${2}

  run docker exec "${TEST_NAME}" sh -c "cat ${CONTAINER_PATH}"
  assert_output "$(cat "${LOCAL_PATH}")"
  assert_success
}
