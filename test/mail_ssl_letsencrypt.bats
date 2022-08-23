load 'test_helper/common'
load 'test_helper/tls'

# Globals referenced from `test_helper/common`:
# TEST_NAME TEST_FQDN TEST_TMP_CONFIG

# Requires maintenance (TODO): Yes
# Can run tests in parallel?: No

# Not parallelize friendly when TEST_NAME is static,
# presently name of test file: `mail_ssl_letsencrypt`.
#
# Also shares a common TEST_TMP_CONFIG local folder,
# Instead of individual PRIVATE_CONFIG copies.
# For this test that is a non-issue, unless run in parallel.


# Applies to all tests:
function setup_file() {
  init_with_defaults

  # Override default to match the hostname we want to test against instead:
  export TEST_FQDN='mail.example.test'

  # Prepare certificates in the letsencrypt supported file structure:
  # Note Certbot uses `privkey.pem`.
  # `fullchain.pem` is currently what's detected, but we're actually providing the equivalent of `cert.pem` here.
  # TODO: Verify format/structure is supported for nginx-proxy + acme-companion (uses `acme.sh` to provision).

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

function teardown() {
  docker rm -f "${TEST_NAME}"
}

# Should detect and choose the cert for FQDN `mail.example.test` (HOSTNAME):
@test "ssl(letsencrypt): Should default to HOSTNAME (mail.example.test)" {
  local TARGET_DOMAIN='mail.example.test'

  local TEST_DOCKER_ARGS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env PERMIT_DOCKER='container'
    --env SSL_TYPE='letsencrypt'
  )

  common_container_setup 'TEST_DOCKER_ARGS'

  #test hostname has certificate files
  _should_have_valid_config "${TARGET_DOMAIN}" 'privkey.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls "${TARGET_DOMAIN}"
  _should_not_support_fqdn_in_cert 'example.test'
}


# Should detect and choose cert for FQDN `example.test` (DOMAINNAME),
# as fallback when no cert for FQDN `mail.example.test` (HOSTNAME) exists:
@test "ssl(letsencrypt): Should fallback to DOMAINNAME (example.test)" {
  local TARGET_DOMAIN='example.test'

  local TEST_DOCKER_ARGS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env PERMIT_DOCKER='container'
    --env SSL_TYPE='letsencrypt'
  )

  common_container_setup 'TEST_DOCKER_ARGS'

  #test domain has certificate files
  _should_have_valid_config "${TARGET_DOMAIN}" 'privkey.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls "${TARGET_DOMAIN}"
  _should_not_support_fqdn_in_cert 'mail.example.test'
}

# When using `acme.json` (Traefik) - a wildcard cert `*.example.test` (SSL_DOMAIN)
# should be extracted and be chosen over an existing FQDN `mail.example.test` (HOSTNAME):
#
# NOTE: Currently all of the `acme.json` configs have the FQDN match a SAN value,
# all Subject CN (`main` in acme.json) are `Smallstep Leaf` which is not an FQDN.
# While valid for that field, it does mean there is no test coverage against `main`.
@test "ssl(letsencrypt): Traefik 'acme.json' (*.example.test)" {
  # This test group changes to certs signed with an RSA Root CA key,
  # These certs all support both FQDNs: `mail.example.test` and `example.test`,
  # Except for the wildcard cert `*.example.test`, which intentionally excluded `example.test` when created.
  # We want to maintain the same FQDN (mail.example.test) between the _acme_ecdsa and _acme_rsa tests.
  local LOCAL_BASE_PATH="${PWD}/test/test-files/ssl/example.test/with_ca/rsa"

  # Change default Root CA cert used for verifying chain of trust with openssl:
  # shellcheck disable=SC2034
  local TEST_CA_CERT="${TEST_FILES_CONTAINER_PATH}/ssl/example.test/with_ca/rsa/ca-cert.rsa.pem"

  function _prepare() {
    # Default `acme.json` for _acme_ecdsa test:
    cp "${LOCAL_BASE_PATH}/ecdsa.acme.json" "${TEST_TMP_CONFIG}/letsencrypt/acme.json"

    # TODO: Provision wildcard certs via Traefik to inspect if `example.test` non-wildcard is also added to the cert.
    # shellcheck disable=SC2034
    local TEST_DOCKER_ARGS=(
      --volume "${TEST_TMP_CONFIG}/letsencrypt/acme.json:/etc/letsencrypt/acme.json:ro"
      --env LOG_LEVEL='trace'
      --env PERMIT_DOCKER='container'
      --env SSL_DOMAIN='*.example.test'
      --env SSL_TYPE='letsencrypt'
    )

    common_container_setup 'TEST_DOCKER_ARGS'
    wait_for_service "${TEST_NAME}" 'changedetector'

    # Wait until the changedetector service startup delay is over:
    repeat_until_success_or_timeout 20 sh -c "$(_get_service_logs 'changedetector') | grep 'Changedetector is ready'"
  }

  # Test `acme.json` extraction works at container startup:
  # It should have already extracted `mail.example.test` from the original mounted `acme.json`.
  function _acme_ecdsa() {
    _should_have_succeeded_at_extraction 'mail.example.test'

    # SSL_DOMAIN set as ENV, but startup should not have match in `acme.json`:
    _should_have_failed_at_extraction '*.example.test' 'mailserver'
    _should_have_valid_config 'mail.example.test' 'key.pem' 'fullchain.pem'

    local ECDSA_KEY_PATH="${LOCAL_BASE_PATH}/key.ecdsa.pem"
    local ECDSA_CERT_PATH="${LOCAL_BASE_PATH}/cert.ecdsa.pem"
    _should_have_expected_files 'mail.example.test' "${ECDSA_KEY_PATH}" "${ECDSA_CERT_PATH}"
  }

  # Test `acme.json` extraction is triggered via change detection:
  # The updated `acme.json` roughly emulates a renewal, but changes from an ECDSA cert to an RSA one.
  # It should replace the cert files in the existing `letsencrypt/live/mail.example.test/` folder.
  function _acme_rsa() {
    _should_extract_on_changes 'mail.example.test' "${LOCAL_BASE_PATH}/rsa.acme.json"
    _should_have_service_restart_count '1'

    local RSA_KEY_PATH="${LOCAL_BASE_PATH}/key.rsa.pem"
    local RSA_CERT_PATH="${LOCAL_BASE_PATH}/cert.rsa.pem"
    _should_have_expected_files 'mail.example.test' "${RSA_KEY_PATH}" "${RSA_CERT_PATH}"
  }

  # Test that `acme.json` also works with wildcard certificates:
  # Additionally tests that SSL_DOMAIN is prioritized when `letsencrypt/live/` already has a HOSTNAME dir available.
  # Wildcard `*.example.test` should extract to `example.test/` in `letsencrypt/live/`:
  function _acme_wildcard() {
    _should_extract_on_changes 'example.test' "${LOCAL_BASE_PATH}/wildcard/rsa.acme.json"
    _should_have_service_restart_count '2'

    # As the FQDN has changed since startup, the Postfix + Dovecot configs should be updated:
    _should_have_valid_config 'example.test' 'key.pem' 'fullchain.pem'

    local WILDCARD_KEY_PATH="${LOCAL_BASE_PATH}/wildcard/key.rsa.pem"
    local WILDCARD_CERT_PATH="${LOCAL_BASE_PATH}/wildcard/cert.rsa.pem"
    _should_have_expected_files 'example.test' "${WILDCARD_KEY_PATH}" "${WILDCARD_CERT_PATH}"

    # These two tests will confirm wildcard support is working, the supported SANs changed:
    # Before (_acme_rsa cert):      `DNS:example.test, DNS:mail.example.test`
    # After  (_acme_wildcard cert): `DNS:*.example.test`
    # The difference in support is:
    # - `example.test` should no longer be valid.
    # - `mail.example.test` should remain valid, but also allow any other subdomain/hostname.
    _should_succesfully_negotiate_tls 'mail.example.test'
    _should_support_fqdn_in_cert 'fake.example.test'
    _should_not_support_fqdn_in_cert 'example.test'
  }

  _prepare

  # Unleash the `acme.json` tests!
  # TODO: Extract methods to separate test cases.
  _acme_ecdsa
  _acme_rsa
  _acme_wildcard
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


#
# Traefik `acme.json` specific
#


# It should log success of extraction for the expected domain and restart Postfix.
function _should_have_succeeded_at_extraction() {
  local EXPECTED_DOMAIN=${1}
  local SERVICE=${2}

  run $(_get_service_logs "${SERVICE}")
  assert_output --partial "_extract_certs_from_acme | Certificate successfully extracted for '${EXPECTED_DOMAIN}'"
}

function _should_have_failed_at_extraction() {
  local EXPECTED_DOMAIN=${1}
  local SERVICE=${2}

  run $(_get_service_logs "${SERVICE}")
  assert_output --partial "_extract_certs_from_acme | Unable to find key and/or cert for '${EXPECTED_DOMAIN}' in '/etc/letsencrypt/acme.json'"
}

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
  assert_output --partial "'/etc/letsencrypt/acme.json' has changed - extracting certificates"
  assert_output --partial "_extract_certs_from_acme | Certificate successfully extracted for '${EXPECTED_DOMAIN}'"
  assert_output --partial 'Restarting services due to detected changes'
  assert_output --partial 'postfix: stopped'
  assert_output --partial 'postfix: started'
  assert_output --partial 'dovecot: stopped'
  assert_output --partial 'dovecot: started'
}

# Ensure change detection is not mistakenly validating against previous change events:
function _should_have_service_restart_count() {
  local NUM_RESTARTS=${1}

  # Count how many times postfix was restarted by the `changedetector` service:
  run docker exec "${TEST_NAME}" sh -c "grep -c 'postfix: started' /var/log/supervisor/changedetector.log"
  assert_output "${NUM_RESTARTS}"
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

  local CMD_LOGS=(docker exec "${TEST_NAME}" "supervisorctl tail -2200 ${SERVICE}")

  # As the `mailserver` service logs are not stored in a file but output to stdout/stderr,
  # The `supervisorctl tail` command won't work; we must instead query via `docker logs`:
  if [[ ${SERVICE} == 'mailserver' ]]
  then
    CMD_LOGS=(docker logs "${TEST_NAME}")
  fi

  echo "${CMD_LOGS[@]}"
}
