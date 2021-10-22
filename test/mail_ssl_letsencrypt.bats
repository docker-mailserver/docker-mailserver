load 'test_helper/common'
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

  # `mail.example.test` (Only FQDN supported by this certificate):
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/cert.ecdsa.pem' 'mail.example.test/fullchain.pem'
  _copy_to_letsencrypt_storage 'example.test/with_ca/ecdsa/key.ecdsa.pem' "mail.example.test/privkey.pem"

  # `example.test` (Only FQDN supported by this certificate):
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

  _should_have_valid_config 'mail.example.test' 'privkey.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls 'mail.example.test'
  _should_not_have_fqdn_in_cert 'example.test'
}


# Should detect and choose cert for FQDN `example.test` (DMS_HOSTNAME_DOMAIN),
# as fallback when no cert for FQDN `mail.example.test` (HOSTNAME) exists:
@test "ssl(letsencrypt): Should fallback to DMS_HOSTNAME_DOMAIN (example.test)" {
  local TARGET_DOMAIN='example.test'

  local TEST_DOCKER_ARGS=(
    --volume "${TEST_TMP_CONFIG}/letsencrypt/${TARGET_DOMAIN}/:/etc/letsencrypt/live/${TARGET_DOMAIN}/:ro"
    --env SSL_TYPE='letsencrypt'
  )

  common_container_setup TEST_DOCKER_ARGS

  _should_have_valid_config 'example.test' 'privkey.pem' 'fullchain.pem'
  _should_succesfully_negotiate_tls 'example.test'
  _should_not_have_fqdn_in_cert 'mail.example.test'
}


# When using `acme.json` (Traefik) - a wildcard cert `*.example.test` (SSL_DOMAIN)
# should be extracted and be chosen over an existing FQDN `mail.example.test` (HOSTNAME):
# _acme_wildcard should verify the FQDN `mail.example.test` is negotiated, not `example.test`.
#
# NOTE: Currently all of the `acme.json` configs have the FQDN match a SAN value,
# all Subject CN (`main` in acme.json) are `Smallstep Leaf` which is not an FQDN.
# While valid for that field, it does mean there is no test coverage against `main`.
@test "ssl(letsencrypt): Traefik 'acme.json' (*.example.test)" {
  # This test group changes to certs signed with an RSA Root CA key,
  # These certs all support both FQDN `mail.example.test` and `example.test`,
  # Except for the wildcard `*.example.test`, which should not support `example.test`.
  local LOCAL_BASE_PATH="${PWD}/test/test-files/ssl/example.test/with_ca/rsa"

  # Change default Root CA cert used for verifying chain of trust with openssl:
  # shellcheck disable=SC2030
  local TEST_CA_CERT="${TEST_FILES_CONTAINER_PATH}/ssl/example.test/with_ca/rsa/ca-cert.rsa.pem"

  function _prepare() {
    # Default `acme.json` for _acme_ecdsa test:
    cp "${LOCAL_BASE_PATH}/ecdsa.acme.json" "${TEST_TMP_CONFIG}/letsencrypt/acme.json"

    # TODO: Provision wildcard certs via Traefik to inspect if `example.test` non-wildcard is also added to the cert.
    # `DMS_DEBUG=1` required for catching logged `inf` output.
    # shellcheck disable=SC2034
    local TEST_DOCKER_ARGS=(
      --volume "${TEST_TMP_CONFIG}/letsencrypt/acme.json:/etc/letsencrypt/acme.json"
      --env SSL_TYPE='letsencrypt'
      --env SSL_DOMAIN='*.example.test'
      --env DMS_DEBUG=1
    )

    common_container_setup TEST_DOCKER_ARGS
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

    # TODO: Make this pass.
    # As the FQDN has changed since startup, the configs need to be updated accordingly.
    # This requires the `changedetector` service event to invoke the same function for TLS configuration
    # that is used during container startup to work correctly. A follow up PR will refactor `setup-stack.sh` for supporting this.
    # _should_have_valid_config 'example.test' 'key.pem' 'fullchain.pem'

    local WILDCARD_KEY_PATH="${LOCAL_BASE_PATH}/wildcard/key.rsa.pem"
    local WILDCARD_CERT_PATH="${LOCAL_BASE_PATH}/wildcard/cert.rsa.pem"
    _should_have_expected_files 'example.test' "${WILDCARD_KEY_PATH}" "${WILDCARD_CERT_PATH}"

    # Verify this works for wildcard certs, it should use `*.example.test` for `mail.example.test` (NOT `example.test`):
    _should_succesfully_negotiate_tls 'mail.example.test'
    # WARNING: This should fail...but requires resolving the above TODO.
    # _should_not_have_fqdn_in_cert 'example.test'
  }

  _prepare

  # Verify the `changedetector` service is running:
  run $(_get_service_logs 'changedetector')
  assert_output --partial 'Start check-for-changes script'

  # Wait until the changedetector startup delay has passed:
  repeat_until_success_or_timeout 20 sh -c "$(_get_service_logs 'changedetector') | grep 'check-for-changes is ready'"

  # Unleash the `acme.json` tests!
  # NOTE: Test failures aren't as helpful here as bats will only identify function calls at this top-level,
  # rather than the actual failing nested function call..
  # TODO: Extract methods to separate test cases.
  _acme_ecdsa
  _acme_rsa
  _acme_wildcard
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

  _has_matching_line 'postconf' "smtpd_tls_chain_files = ${LE_KEY_PATH} ${LE_CERT_PATH}"
  _has_matching_line 'doveconf' "ssl_cert = <${LE_CERT_PATH}"
  # `-P` is required to prevent redacting secrets
  _has_matching_line 'doveconf -P' "ssl_key = <${LE_KEY_PATH}"
}

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
  assert_output --partial "Unable to find key for '${EXPECTED_DOMAIN}' in '/etc/letsencrypt/acme.json'"
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
  assert_output --partial "'/etc/letsencrypt/acme.json' has changed, extracting certs"
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

  run docker exec "${TEST_NAME}" /bin/sh -c "supervisorctl tail changedetector | grep -c 'postfix: started'"
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
# TLS
#


# For certs actually provisioned from LetsEncrypt the Root CA cert should not need to be provided,
# as it would already be available by default in `/etc/ssl/certs`, requiring only the cert chain (fullchain.pem).
function _should_succesfully_negotiate_tls() {
  local FQDN=${1}
  local CONTAINER_NAME=${2:-${TEST_NAME}}
  local CA_CERT=${3:-${TEST_CA_CERT}}

  # Postfix and Dovecot are ready:
  wait_for_smtp_port_in_container_to_respond "${CONTAINER_NAME}"
  wait_for_tcp_port_in_container 993 "${CONTAINER_NAME}"

  # Root CA cert should be present in the container:
  assert docker exec "${CONTAINER_NAME}" [ -f "${CA_CERT}" ]

  local PORTS=(25 587 465 143 993)
  for PORT in "${PORTS[@]}"
  do
    _negotiate_tls "${FQDN}" "${PORT}"
  done
}

function _negotiate_tls() {
  local FQDN=${1}
  local PORT=${2}
  local CONTAINER_NAME=${3:-${TEST_NAME}}
  local CA_CERT=${4:-${TEST_CA_CERT}}

  local CMD_OPENSSL_VERIFY
  CMD_OPENSSL_VERIFY=$(_generate_openssl_cmd "${PORT}")

  # Should fail as a chain of trust is required to verify successfully:
  run docker exec "${CONTAINER_NAME}" /bin/sh -c "${CMD_OPENSSL_VERIFY}"
  assert_output --partial 'Verification error: unable to verify the first certificate'

  # Provide the Root CA cert for successful verification:
  CMD_OPENSSL_VERIFY=$(_generate_openssl_cmd "${PORT}" "-CAfile ${CA_CERT}")
  run docker exec "${CONTAINER_NAME}" /bin/sh -c "${CMD_OPENSSL_VERIFY}"
  assert_output --partial 'Verification: OK'

  _should_have_fqdn_in_cert "${FQDN}" "${PORT}"
}

function _should_have_fqdn_in_cert() {
  local FQDN
  FQDN=$(escape_fqdn "${1}")

  _get_fqdns_for_cert "$@"
  assert_output --regexp "Subject: CN = ${FQDN}|DNS:${FQDN}"
}

function _should_not_have_fqdn_in_cert() {
  local FQDN
  FQDN=$(escape_fqdn "${1}")

  _get_fqdns_for_cert "$@"
  refute_output --regexp "Subject: CN = ${FQDN}|DNS:${FQDN}"
}

# Escapes `*` and `.` so the FQDN literal can be used in regex queries
function escape_fqdn() {
  # shellcheck disable=SC2001
  sed 's|[\*\.]|\\&|g' <<< "${1}"
}

function _get_fqdns_for_cert() {
  local FQDN=${1}
  local PORT=${2:-'25'}
  local CONTAINER_NAME=${3:-${TEST_NAME}}
  local CA_CERT=${4:-${TEST_CA_CERT}}

  # `-servername` is for SNI, where the port may be for a service that serves multiple certs,
  # and needs a specific FQDN to return the correct cert. Such as a reverse-proxy.
  local EXTRA_ARGS="-servername ${FQDN} -CAfile ${CA_CERT}"
  local CMD_OPENSSL_VERIFY
  # eg: "timeout 1 openssl s_client -connect localhost:25 -starttls smtp ${EXTRA_ARGS} 2>/dev/null"
  CMD_OPENSSL_VERIFY=$(_generate_openssl_cmd "${PORT}" "${EXTRA_ARGS}")

  # Takes the result of the openssl output to return the x509 certificate,
  # We then check that for any matching FQDN entries:
  # main == `Subject CN = <FQDN>`, sans == `DNS:<FQDN>`
  local CMD_FILTER_FQDN="openssl x509 -noout -text | egrep 'Subject: CN = |DNS:'"

  run docker exec "${CONTAINER_NAME}" /bin/sh -c "${CMD_OPENSSL_VERIFY} | ${CMD_FILTER_FQDN}"
}

function _generate_openssl_cmd() {
  # Using a HOST of `localhost` will not have issues with `/etc/hosts` matching,
  # since hostname may not be match correctly in `/etc/hosts` during tests when checking cert validity.
  local HOST='localhost'
  local PORT=${1}
  local EXTRA_ARGS=${2}

  # `echo '' | openssl ...` is a common approach for providing input to `openssl` command which waits on input to exit.
  # While the command is still successful it does result with `500 5.5.2 Error: bad syntax` being included in the response.
  # `timeout 1` instead of the empty echo pipe approach seems to work better instead.
  local CMD_OPENSSL="timeout 1 openssl s_client -connect ${HOST}:${PORT}"

  # STARTTLS ports need to add a hint:
  if [[ ${PORT} =~ ^(25|587)$ ]]
  then
    CMD_OPENSSL="${CMD_OPENSSL} -starttls smtp"
  elif [[ ${PORT} == 143 ]]
  then
    CMD_OPENSSL="${CMD_OPENSSL} -starttls imap"
  elif [[ ${PORT} == 110 ]]
  then
    CMD_OPENSSL="${CMD_OPENSSL} -starttls pop3"
  fi

  echo "${CMD_OPENSSL} ${EXTRA_ARGS} 2>/dev/null"
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
  # The `supervisorctl tail` command won't work; must instead query via `docker logs`:
  if [[ ${SERVICE} == 'mailserver' ]]
  then
    CMD_LOGS=(docker logs "${TEST_NAME}")
  fi

  echo "${CMD_LOGS[@]}"
}
