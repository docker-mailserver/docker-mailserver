load 'test_helper/common'

# Applies to all tests:
function setup_file() {
  init_with_defaults

  # Override default to match the hostname we want to test against instead:
  export TEST_FQDN='mail.example.test'

  # Prepare certificates in the letsencrypt supported file structure:
  # Note Certbot uses `privkey.pem`.
  # `fullchain.pem` is currently what's detected, but we're actually providing the equivalent of `cert.pem` here.

  # `mail.example.test` (Only this FQDN is supported by this certificate):
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/cert.ecdsa.pem' 'mail.example.test/fullchain.pem'
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/key.ecdsa.pem' "mail.example.test/privkey.pem"

  # `example.test` (Only this FQDN is supported by this certificate):
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/cert.rsa.pem' 'example.test/fullchain.pem'
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/key.rsa.pem' 'example.test/privkey.pem'
}

# Not used
# function teardown_file() {
# }

# Applies per test:
function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  docker rm -f "${TEST_NAME}"
  run_teardown_file_if_necessary
}


# this test must come first to reliably identify when to run setup_file
@test "first" {
  skip 'Starting testing of letsencrypt SSL'
}


# Should detect and choose the cert for FQDN `mail.example.test` (HOSTNAME):
@test "ssl(letsencrypt): Should default to HOSTNAME (mail.example.test)" {
  local TARGET_DOMAIN='mail.example.test'

  local TEST_DOCKER_ARGS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env SSL_TYPE='letsencrypt'
  )

  common_container_setup TEST_DOCKER_ARGS

  #test hostname has certificate files
  _should_have_valid_config "${TARGET_DOMAIN}" 'privkey.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls
}


# Should detect and choose cert for FQDN `example.test` (DOMAINNAME),
# as fallback when no cert for FQDN `mail.example.test` (HOSTNAME) exists:
@test "ssl(letsencrypt): Should fallback to DOMAINNAME (example.test)" {
  local TARGET_DOMAIN='example.test'

  local TEST_DOCKER_ARGS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env SSL_TYPE='letsencrypt'
  )

  common_container_setup TEST_DOCKER_ARGS

  #test domain has certificate files
  _should_have_valid_config "${TARGET_DOMAIN}" 'privkey.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls
}


# acme.json updates
@test "ssl(letsencrypt): Traefik 'acme.json' (*.example.test)" {
  local LOCAL_BASE_PATH="${PWD}/test/test-files/ssl/example.test/with_ca/rsa"

  function _prepare() {
    # Default `acme.json` for _extract_at_startup test:
    cp "${LOCAL_BASE_PATH}/ecdsa.acme.json" "${TEST_TMP_CONFIG}/letsencrypt/acme.json"

    # `DMS_DEBUG=1` required for catching logged `inf` output.
    # shellcheck disable=SC2034
    local TEST_DOCKER_ARGS=(
      --volume "${TEST_TMP_CONFIG}/letsencrypt/acme.json:/etc/letsencrypt/acme.json:ro"
      --env SSL_TYPE='letsencrypt'
      --env SSL_DOMAIN='*.example.test'
      --env DMS_DEBUG=1
    )

    common_container_setup TEST_DOCKER_ARGS
    wait_for_service "${TEST_NAME}" 'changedetector'

    # Wait until the changedetector service startup delay is over:
    repeat_until_success_or_timeout 20 sh -c "$(_get_service_logs 'changedetector') | grep 'check-for-changes is ready'"
  }

  # "can extract certs from acme.json"
  function _extract_at_startup() {
    local ECDSA_KEY_PATH="${LOCAL_BASE_PATH}/key.ecdsa.pem"
    local ECDSA_CERT_PATH="${LOCAL_BASE_PATH}/cert.ecdsa.pem"
    _should_have_expected_files 'mail.example.test' "${ECDSA_KEY_PATH}" "${ECDSA_CERT_PATH}"
  }

  # "can detect changes"
  function _extract_at_change_detection() {
    _should_extract_on_changes 'example.test' "${LOCAL_BASE_PATH}/wildcard/rsa.acme.json"

    local WILDCARD_KEY_PATH="${LOCAL_BASE_PATH}/wildcard/key.rsa.pem"
    local WILDCARD_CERT_PATH="${LOCAL_BASE_PATH}/wildcard/cert.rsa.pem"
    _should_have_expected_files 'example.test' "${WILDCARD_KEY_PATH}" "${WILDCARD_CERT_PATH}"
  }

  _prepare

  # Unleash the `acme.json` tests!
  # NOTE: Test failures aren't as helpful here as bats will only identify function calls at this top-level,
  # rather than the actual failing nested function call..
  # TODO: Extract methods to separate test cases.
  _extract_at_startup
  _extract_at_change_detection
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


#
# Traefik `acme.json` specific
#


# Replace the mounted `acme.json` and wait to see if changes were detected.
function _should_extract_on_changes() {
  local EXPECTED_DOMAIN=${1}
  local ACME_JSON=${2}

  cp "${ACME_JSON}" "${TEST_TMP_CONFIG}/letsencrypt/acme.json"
  # Change detection takes a little over 5 seconds to complete (restart services)
  sleep 10

  # Expected log lines from the changedetector service:
  run $(_get_service_logs 'changedetector')
  assert_output --partial 'Change detected'
  assert_output --partial "'/etc/letsencrypt/acme.json' has changed, extracting certs"
  assert_output --partial "_extract_certs_from_acme | Certificate successfully extracted for '${EXPECTED_DOMAIN}'"
  assert_output --partial 'Restarting services due to detected changes'
  assert_output --partial 'postfix: stopped'
  assert_output --partial 'postfix: started'
  assert_output --partial 'dovecot: stopped'
  assert_output --partial 'dovecot: started'
}

# Extracted cert files from `acme.json` have content matching the expected reference files:
function _should_have_expected_files() {
  local LE_BASE_PATH="/etc/letsencrypt/live/${1}"
  local LE_KEY_PATH="${LE_BASE_PATH}/key.pem"
  local LE_CERT_PATH="${LE_BASE_PATH}/fullchain.pem"
  local EXPECTED_KEY_PATH=${2}
  local EXPECTED_CERT_PATH=${3}

  _should_be_equal_in_content "${LE_KEY_PATH}" "${EXPECTED_KEY_PATH}"
  _should_be_equal_in_content "${LE_CERT_PATH}" "${EXPECTED_CERT_PATH}"
}


#
# Misc
#


# Rename test certificate files to match the expected file structure for letsencrypt:
function _copy_to_letsencrypt_storage() {
  local SRC=${1}
  local DEST=${2}

  local FQDN_DIR
  FQDN_DIR=$(echo "${DEST}" | cut -d '/' -f1)
  mkdir -p "${TEST_TMP_CONFIG}/letsencrypt/${FQDN_DIR}"

  cp "${PWD}/test/test-files/ssl/${SRC}" "${TEST_TMP_CONFIG}/letsencrypt/${DEST}"
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
