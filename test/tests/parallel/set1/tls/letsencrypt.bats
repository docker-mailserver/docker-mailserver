load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/change-detection"
load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/tls"

BATS_TEST_NAME_PREFIX='[Security] (TLS) (SSL_TYPE=letsencrypt) '
CONTAINER1_NAME='dms-test_tls-letsencrypt_default-hostname'
CONTAINER2_NAME='dms-test_tls-letsencrypt_fallback-domainname'
CONTAINER3_NAME='dms-test_tls-letsencrypt_support-acme-json'
export TEST_FQDN='mail.example.test'

function teardown() { _default_teardown ; }

# Similar to BATS `setup()` method, but invoked manually after
# CONTAINER_NAME has been adjusted for the running testcase.
function _initial_setup() {
  _init_with_defaults

  # Prepare certificates in the letsencrypt supported file structure:
  # NOTE: Certbot uses `privkey.pem`.
  # `fullchain.pem` is currently what's detected, but we're actually providing the equivalent of `cert.pem` here.
  # TODO: Verify format/structure is supported for nginx-proxy + acme-companion (uses `acme.sh` to provision).

  # `mail.example.test` (Only this FQDN is supported by this certificate):
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/cert.ecdsa.pem' 'mail.example.test/fullchain.pem'
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/key.ecdsa.pem' "mail.example.test/privkey.pem"

  # `example.test` (Only this FQDN is supported by this certificate):
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/cert.rsa.pem' 'example.test/fullchain.pem'
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/key.rsa.pem' 'example.test/privkey.pem'
}

# Should detect and choose the cert for FQDN `mail.example.test` (HOSTNAME):
@test "Should default to HOSTNAME (${TEST_FQDN})" {
  export CONTAINER_NAME=${CONTAINER1_NAME}
  _initial_setup

  local TARGET_DOMAIN=${TEST_FQDN}
  local CUSTOM_SETUP_ARGUMENTS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env PERMIT_DOCKER='container'
    --env SSL_TYPE='letsencrypt'
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Test that certificate files exist for the configured `hostname`:
  _should_have_valid_config "${TARGET_DOMAIN}" 'privkey.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls "${TARGET_DOMAIN}"
  _should_not_support_fqdn_in_cert 'example.test'
}

# Should detect and choose cert for FQDN `example.test` (DOMAINNAME),
# as fallback when no cert for FQDN `mail.example.test` (HOSTNAME) exists:
@test "Should fallback to DOMAINNAME (example.test)" {
  export CONTAINER_NAME=${CONTAINER2_NAME}
  _initial_setup

  local TARGET_DOMAIN='example.test'
  local CUSTOM_SETUP_ARGUMENTS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env PERMIT_DOCKER='container'
    --env SSL_TYPE='letsencrypt'
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

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
# While not using a FQDN is valid for that field,
# it does mean there is no test coverage against the `acme.json` field `main`.
@test "Traefik 'acme.json' (*.example.test)" {
  export CONTAINER_NAME=${CONTAINER3_NAME}
  _initial_setup

  # Override the `_initial_setup()` default Root CA cert (used for verifying the chain of trust via `openssl`):
  # shellcheck disable=SC2034
  local TEST_CA_CERT="${TEST_FILES_CONTAINER_PATH}/ssl/example.test/with_ca/rsa/ca-cert.rsa.pem"

  # This test group switches to certs that are signed with an RSA Root CA key instead.
  # All of these certs support both FQDNs (`mail.example.test` and `example.test`),
  # Except for the wildcard cert (`*.example.test`), that was created with `example.test` intentionally excluded from SAN.
  # We want to maintain the same FQDN (`mail.example.test`) between the _acme_ecdsa and _acme_rsa tests.
  local LOCAL_BASE_PATH="${PWD}/test/test-files/ssl/example.test/with_ca/rsa"

  function _prepare() {
    # Default `acme.json` for _acme_ecdsa test:
    cp "${LOCAL_BASE_PATH}/ecdsa.acme.json" "${TEST_TMP_CONFIG}/letsencrypt/acme.json"

    # TODO: Provision wildcard certs via Traefik to inspect if `example.test` non-wildcard is also added to the cert.
    local CUSTOM_SETUP_ARGUMENTS=(
      --volume "${TEST_TMP_CONFIG}/letsencrypt/acme.json:/etc/letsencrypt/acme.json:ro"
      --env LOG_LEVEL='trace'
      --env PERMIT_DOCKER='container'
      --env SSL_DOMAIN='*.example.test'
      --env SSL_TYPE='letsencrypt'
    )
    _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
    _wait_for_service 'changedetector'
  }

  # Test `acme.json` extraction works at container startup:
  # It should have already extracted `mail.example.test` from the original mounted `acme.json`.
  function _acme_ecdsa() {
    # SSL_DOMAIN value should not be present in current `acme.json`:
    _should_fail_to_extract_for_wildcard_env
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

    local RSA_KEY_PATH="${LOCAL_BASE_PATH}/key.rsa.pem"
    local RSA_CERT_PATH="${LOCAL_BASE_PATH}/cert.rsa.pem"
    _should_have_expected_files 'mail.example.test' "${RSA_KEY_PATH}" "${RSA_CERT_PATH}"
  }

  # Test that `acme.json` also works with wildcard certificates:
  # Additionally tests that SSL_DOMAIN is prioritized when `letsencrypt/live/` already has a HOSTNAME dir available.
  # Wildcard `*.example.test` should extract to `example.test/` in `letsencrypt/live/`:
  function _acme_wildcard() {
    _should_extract_on_changes 'example.test' "${LOCAL_BASE_PATH}/wildcard/rsa.acme.json"

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
  _run_in_container_bash "${1} | grep '${2}'"
  assert_output "${2}"
}

#
# Traefik `acme.json` specific
#

function _should_fail_to_extract_for_wildcard_env() {
  # Set as value for ENV `SSL_DOMAIN`, but during startup it should fail to find a match in the current `acme.json`:
  local DOMAIN_WILDCARD='*.example.test'
  # The expected domain to be found and extracted instead (value from container `--hostname`):
  local DOMAIN_MAIL='mail.example.test'

  # /var/log/mail/mail.log is not equivalent to stdout content,
  # Relevant log content only available via docker logs:
  run docker logs "${CONTAINER_NAME}"
  assert_output --partial "_extract_certs_from_acme | Unable to find key and/or cert for '${DOMAIN_WILDCARD}' in '/etc/letsencrypt/acme.json'"
  assert_output --partial "_extract_certs_from_acme | Certificate successfully extracted for '${DOMAIN_MAIL}'"
}

# Replace the mounted `acme.json` and wait to see if changes were detected.
function _should_extract_on_changes() {
  local EXPECTED_DOMAIN=${1}
  local ACME_JSON=${2}

  cp "${ACME_JSON}" "${TEST_TMP_CONFIG}/letsencrypt/acme.json"
  _wait_until_change_detection_event_completes

  # Expected log lines from the changedetector service:
  run _get_logs_since_last_change_detection "${CONTAINER_NAME}"
  assert_output --partial "'/etc/letsencrypt/acme.json' has changed - extracting certificates"
  assert_output --partial "_extract_certs_from_acme | Certificate successfully extracted for '${EXPECTED_DOMAIN}'"
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

  if ! cp "${PWD}/test/test-files/ssl/${SRC}" "${TEST_TMP_CONFIG}/letsencrypt/${DEST}"; then
    echo "Could not copy cert file '${SRC}'' to '${DEST}'" >&2
    exit 1
  fi
}

function _should_be_equal_in_content() {
  local CONTAINER_PATH=${1}
  local LOCAL_PATH=${2}

  _run_in_container /bin/bash -c "cat ${CONTAINER_PATH}"
  assert_output "$(cat "${LOCAL_PATH}")"
  assert_success
}
