load 'test_helper/common'

# Applies per test:
function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  docker rm -f "${TEST_NAME}"
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


# Should detect and choose the cert for FQDN `mail.my-domain.com` (HOSTNAME):
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
}


# Should detect and choose cert for FQDN `my-domain.com` (DOMAINNAME),
# as fallback when no cert for FQDN `mail.my-domain.com` (HOSTNAME) exists:
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
}


# acme.json updates
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
  wait_for_service "${TEST_NAME}" 'changedetector'

  # Wait until the changedetector service startup delay is over:
  repeat_until_success_or_timeout 20 sh -c "$(_get_service_logs 'changedetector') | grep 'check-for-changes is ready'"

  # "can extract certs from acme.json"
  local CONTAINER_BASE_PATH='/etc/letsencrypt/live/mail.my-domain.com'
  local LOCAL_BASE_PATH
  LOCAL_BASE_PATH="${TEST_TMP_CONFIG}/letsencrypt/mail.my-domain.com"

  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/key.pem" "${LOCAL_BASE_PATH}/privkey.pem"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/fullchain.pem" "${LOCAL_BASE_PATH}/fullchain.pem"

  # "can detect changes"
  cp "${TEST_TMP_CONFIG}/letsencrypt/acme-changed.json" "${TEST_TMP_CONFIG}/acme.json"
  sleep 10

  run docker exec "${TEST_NAME}" /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"
  assert_output --partial "Change detected"

  LOCAL_BASE_PATH="${TEST_TMP_CONFIG}/letsencrypt/changed"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/key.pem" "${LOCAL_BASE_PATH}/key.pem"
  _should_be_equal_in_content "${CONTAINER_BASE_PATH}/fullchain.pem" "${LOCAL_BASE_PATH}/fullchain.pem"
}


# this test is only there to reliably mark the end for the teardown_file
@test "last" {
  skip 'Finished testing of letsencrypt SSL'
}


#
# Test Methods
#


# Check that Dovecot and Postfix are configured to use a cert for the expected FQDN:
function _should_have_valid_config() {
  local EXPECTED_FQDN=${1}
  local LE_KEY_PATH="/etc/letsencrypt/live/${EXPECTED_FQDN}/${2}"
  local LE_CERT_PATH="/etc/letsencrypt/live/${EXPECTED_FQDN}/${3}"

  _has_matching_line 'postconf' "smtpd_tls_chain_files = ${LE_KEY_PATH} ${LE_CERT_PATH}"
  _has_matching_line 'doveconf' "ssl_cert = <${LE_CERT_PATH}"
  # `-P` is required to prevent redacting secrets
  _has_matching_line 'doveconf -P' "ssl_key = <${LE_KEY_PATH}"
}

# CMD ${1} run in container with output checked to match value of ${2}:
function _has_matching_line() {
  run docker exec "${TEST_NAME}" sh -c "${1} | grep '${2}'"
  assert_output "${2}"
}

function _should_succesfully_negotiate_tls() {
  run docker exec "${TEST_NAME}" sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
  run docker exec "${TEST_NAME}" sh -c "timeout 1 openssl s_client -connect 0.0.0.0:465 -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

function _should_be_equal_in_content() {
  local CONTAINER_PATH=${1}
  local LOCAL_PATH=${2}

  run docker exec "${TEST_NAME}" sh -c "cat ${CONTAINER_PATH}"
  assert_output "$(cat "${LOCAL_PATH}")"
  assert_success
}

function _get_service_logs() {
  local SERVICE=${1:-'mailserver'}

  local CMD_LOGS=(docker exec "${TEST_NAME}" "supervisorctl tail ${SERVICE}")

  # As the `mailserver` service logs are not stored in a file but output to stdout/stderr,
  # The `supervisorctl tail` command won't work; we must instead query via `docker logs`:
  if [[ ${SERVICE} == 'mailserver' ]]
  then
    CMD_LOGS=(docker logs "${TEST_NAME}")
  fi

  echo "${CMD_LOGS[@]}"
}
