load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Security] (TLS) (SSL_TYPE=manual) '
CONTAINER_NAME='dms-test_tls-manual'

function setup_file() {
  # Internal copies made by `scripts/helpers/ssl.sh`:
  export PRIMARY_KEY='/etc/dms/tls/key'
  export PRIMARY_CERT='/etc/dms/tls/cert'
  export FALLBACK_KEY='/etc/dms/tls/fallback_key'
  export FALLBACK_CERT='/etc/dms/tls/fallback_cert'

  # Volume mounted certs:
  export SSL_KEY_PATH='/config/ssl/key.ecdsa.pem'
  export SSL_CERT_PATH='/config/ssl/cert.ecdsa.pem'
  export SSL_ALT_KEY_PATH='/config/ssl/key.rsa.pem'
  export SSL_ALT_CERT_PATH='/config/ssl/cert.rsa.pem'

  export TEST_DOMAIN='example.test'

  local CUSTOM_SETUP_ARGUMENTS=(
    --volume "${PWD}/test/test-files/ssl/${TEST_DOMAIN}/with_ca/ecdsa/:/config/ssl/:ro"
    --env LOG_LEVEL='trace'
    --env SSL_TYPE='manual'
    --env TLS_LEVEL='modern'
    --env SSL_KEY_PATH="${SSL_KEY_PATH}"
    --env SSL_CERT_PATH="${SSL_CERT_PATH}"
    --env SSL_ALT_KEY_PATH="${SSL_ALT_KEY_PATH}"
    --env SSL_ALT_CERT_PATH="${SSL_ALT_CERT_PATH}"
  )

  _init_with_defaults
  # Override the default set in `_common_container_setup`:
  export TEST_FQDN="mail.${TEST_DOMAIN}"
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test "ENV vars provided are valid files" {
  _run_in_container [ -f "${SSL_CERT_PATH}" ]
  assert_success

  _run_in_container [ -f "${SSL_KEY_PATH}" ]
  assert_success

  _run_in_container [ -f "${SSL_ALT_CERT_PATH}" ]
  assert_success

  _run_in_container [ -f "${SSL_ALT_KEY_PATH}" ]
  assert_success
}

@test "manual configuration is correct" {
  local DOVECOT_CONFIG_SSL='/etc/dovecot/conf.d/10-ssl.conf'

  _run_in_container grep '^smtpd_tls_chain_files =' '/etc/postfix/main.cf'
  assert_success
  assert_output "smtpd_tls_chain_files = ${PRIMARY_KEY} ${PRIMARY_CERT} ${FALLBACK_KEY} ${FALLBACK_CERT}"

  _run_in_container grep '^ssl_key =' "${DOVECOT_CONFIG_SSL}"
  assert_success
  assert_output "ssl_key = <${PRIMARY_KEY}"

  _run_in_container grep '^ssl_cert =' "${DOVECOT_CONFIG_SSL}"
  assert_success
  assert_output "ssl_cert = <${PRIMARY_CERT}"

  _run_in_container grep '^ssl_alt_key =' "${DOVECOT_CONFIG_SSL}"
  assert_success
  assert_output "ssl_alt_key = <${FALLBACK_KEY}"

  _run_in_container grep '^ssl_alt_cert =' "${DOVECOT_CONFIG_SSL}"
  assert_success
  assert_output "ssl_alt_cert = <${FALLBACK_CERT}"
}

@test "manual configuration copied files correctly " {
  _run_in_container cmp -s "${PRIMARY_KEY}" "${SSL_KEY_PATH}"
  assert_success
  _run_in_container cmp -s "${PRIMARY_CERT}" "${SSL_CERT_PATH}"
  assert_success

  # Fallback cert
  _run_in_container cmp -s "${FALLBACK_KEY}" "${SSL_ALT_KEY_PATH}"
  assert_success
  _run_in_container cmp -s "${FALLBACK_CERT}" "${SSL_ALT_CERT_PATH}"
  assert_success
}

@test "manual cert works correctly" {
  _wait_for_tcp_port_in_container 587

  local TEST_COMMAND=(timeout 1 openssl s_client -connect mail.example.test:587 -starttls smtp)
  local RESULT

  # Should fail as a chain of trust is required to verify successfully:
  RESULT=$(docker exec "${CONTAINER_NAME}" "${TEST_COMMAND[@]}" | grep 'Verification error:')
  assert_equal "${RESULT}" 'Verification error: unable to verify the first certificate'

  # Provide the Root CA cert for successful verification:
  local CA_CERT='/config/ssl/ca-cert.ecdsa.pem'
  assert docker exec "${CONTAINER_NAME}" [ -f "${CA_CERT}" ]
  RESULT=$(docker exec "${CONTAINER_NAME}" "${TEST_COMMAND[@]}" -CAfile "${CA_CERT}" | grep 'Verification: OK')
  assert_equal "${RESULT}" 'Verification: OK'
}

@test "manual cert changes are picked up by check-for-changes" {
  printf '%s' 'someThingsChangedHere' \
    >>"$(pwd)/test/test-files/ssl/${TEST_DOMAIN}/with_ca/ecdsa/key.ecdsa.pem"

  run timeout 15 docker exec "${CONTAINER_NAME}" bash -c "tail -F /var/log/supervisor/changedetector.log | sed '/Manual certificates have changed/ q'"
  assert_success

  sed -i '/someThingsChangedHere/d' "$(pwd)/test/test-files/ssl/${TEST_DOMAIN}/with_ca/ecdsa/key.ecdsa.pem"
}
