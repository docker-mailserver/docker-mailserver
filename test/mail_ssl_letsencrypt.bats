load 'test_helper/common'

function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

function setup_file() {
  local PRIVATE_CONFIG CONTAINER_NAME VOLUME_CONFIG VOLUME_TEST_FILES VOLUME_LETSENCRYPT
  VOLUME_TEST_FILES="$(pwd)/test/test-files:/tmp/docker-mailserver-test:ro"


  CONTAINER_NAME='mail_lets_acme_json'
  PRIVATE_CONFIG="$(duplicate_config_for_container . "${CONTAINER_NAME}")"
  VOLUME_CONFIG="${PRIVATE_CONFIG}:/tmp/docker-mailserver"
  VOLUME_LETSENCRYPT="${PRIVATE_CONFIG}/acme.json:/etc/letsencrypt/acme.json:ro"
  # Copy will mounted as volume and overwritten with another `acme.json` during testing:
  cp "$(private_config_path "${CONTAINER_NAME}")/letsencrypt/acme.json" "$(private_config_path "${CONTAINER_NAME}")/acme.json"

  docker run -d --name "${CONTAINER_NAME}" \
    -v "${VOLUME_CONFIG}" \
    -v "${VOLUME_TEST_FILES}" \
    -v "${VOLUME_LETSENCRYPT}" \
    -e DMS_DEBUG=1 \
    -e SSL_TYPE='letsencrypt' \
    -e SSL_DOMAIN='*.example.com' \
    -h 'mail.my-domain.com' \
    -t "${NAME}"
  wait_for_finished_setup_in_container "${CONTAINER_NAME}"
}

function teardown_file() {
  docker rm -f mail_lets_domain
  docker rm -f mail_lets_hostname
  docker rm -f mail_lets_acme_json
}

# this test must come first to reliably identify when to run setup_file
@test "first" {
  skip 'Starting testing of letsencrypt SSL'
}

@test "checking ssl: letsencrypt configuration is correct" {
}

@test "ssl(letsencrypt): Should default to HOSTNAME (mail.my-domain.com)" {
  CONTAINER_NAME='mail_lets_hostname'
  PRIVATE_CONFIG="$(duplicate_config_for_container . "${CONTAINER_NAME}")"
  VOLUME_CONFIG="${PRIVATE_CONFIG}:/tmp/docker-mailserver"
  VOLUME_LETSENCRYPT="${PRIVATE_CONFIG}/letsencrypt/mail.my-domain.com:/etc/letsencrypt/live/mail.my-domain.com"

  docker run -d --name "${CONTAINER_NAME}" \
    -v "${VOLUME_CONFIG}" \
    -v "${VOLUME_TEST_FILES}" \
    -v "${VOLUME_LETSENCRYPT}" \
    -e DMS_DEBUG=0 \
    -e SSL_TYPE='letsencrypt' \
    -h 'mail.my-domain.com' \
    -t "${NAME}"
  wait_for_finished_setup_in_container "${CONTAINER_NAME}"

  #test hostname has certificate files
  _should_have_valid_config 'mail.my-domain.com' 'privkey.pem' 'fullchain.pem' "${CONTAINER_NAME}"
  _should_succesfully_negotiate_tls "${CONTAINER_NAME}"
}

@test "checking ssl: letsencrypt cert works correctly" {
}

@test "ssl(letsencrypt): Should fallback to DOMAINNAME (my-domain.com)" {
  CONTAINER_NAME='mail_lets_domain'
  PRIVATE_CONFIG="$(duplicate_config_for_container . "${CONTAINER_NAME}")"
  VOLUME_CONFIG="${PRIVATE_CONFIG}:/tmp/docker-mailserver"
  VOLUME_LETSENCRYPT="${PRIVATE_CONFIG}/letsencrypt/my-domain.com:/etc/letsencrypt/live/my-domain.com"

  docker run -d --name "${CONTAINER_NAME}" \
    -v "${VOLUME_CONFIG}" \
    -v "${VOLUME_TEST_FILES}" \
    -v "${VOLUME_LETSENCRYPT}" \
    -e DMS_DEBUG=0 \
    -e SSL_TYPE='letsencrypt' \
    -h 'mail.my-domain.com' \
    -t "${NAME}"
  wait_for_finished_setup_in_container "${CONTAINER_NAME}"

  #test domain has certificate files
  _should_have_valid_config 'my-domain.com' 'key.pem' 'fullchain.pem' "${CONTAINER_NAME}"
  _should_succesfully_negotiate_tls "${CONTAINER_NAME}"
}

#
# acme.json updates
#


@test "ssl(letsencrypt): Traefik 'acme.json' (*.example.com)" {
  # "checking changedetector: server is ready"
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "ps aux | grep '/bin/bash /usr/local/bin/check-for-changes.sh'"
  assert_success

  # "can extract certs from acme.json"
  local CONTAINER_BASE_PATH='/etc/letsencrypt/live/mail.my-domain.com'
  local LOCAL_BASE_PATH
  LOCAL_BASE_PATH="$(private_config_path "${CONTAINER_NAME}")/letsencrypt/mail.my-domain.com"

  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/key.pem" "${LOCAL_BASE_PATH}/privkey.pem" "${CONTAINER_NAME}"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/fullchain.pem" "${LOCAL_BASE_PATH}/fullchain.pem" "${CONTAINER_NAME}"

  # "can detect changes"
  cp "$(private_config_path "${CONTAINER_NAME}")/letsencrypt/acme-changed.json" "$(private_config_path "${CONTAINER_NAME}")/acme.json"
  sleep 11

  run docker exec "${CONTAINER_NAME}" /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"
  assert_output --partial "Change detected"

  local CONTAINER_BASE_PATH='/etc/letsencrypt/live/mail.my-domain.com'
  local LOCAL_BASE_PATH
  LOCAL_BASE_PATH="$(private_config_path "${CONTAINER_NAME}")/letsencrypt/changed"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/key.pem" "${LOCAL_BASE_PATH}/key.pem" "${CONTAINER_NAME}"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/fullchain.pem" "${LOCAL_BASE_PATH}/fullchain.pem" "${CONTAINER_NAME}"
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
  local CONTAINER_NAME=${4}

  _has_matching_line "postconf | grep 'smtpd_tls_chain_files = ${LE_KEY_PATH} ${LE_CERT_PATH}'"
  _has_matching_line "doveconf | grep 'ssl_cert = <${LE_CERT_PATH}'"
  # `-P` is required to prevent redacting secrets
  _has_matching_line "doveconf -P | grep 'ssl_key = <${LE_KEY_PATH}'"
}

function _has_matching_line() {
  run docker exec "${CONTAINER_NAME}" /bin/sh -c "${1} | wc -l"
  assert_success
  assert_output 1
}

function _should_succesfully_negotiate_tls() {
  local CONTAINER_NAME=${1}

  run docker exec "${CONTAINER_NAME}" /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
  run docker exec "${CONTAINER_NAME}" /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:465 -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

function _should_be_equal_in_content() {
  local CONTAINER_PATH=${1}
  local LOCAL_PATH=${2}
  local CONTAINER_NAME=${3}

  run docker exec "${CONTAINER_NAME}" sh -c "cat ${CONTAINER_PATH}"
  assert_output "$(cat "${LOCAL_PATH}")"
  assert_success
}
