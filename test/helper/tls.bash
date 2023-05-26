#!/bin/bash

# TODO: Functions need better documentation / or documentation at all (adhere to doc conventions!)
# ? ABOUT: Functions defined here can be used when testing encrypt-related functionality.
# ? NOTE: `_should_*` methods are useful for common high-level functionality.

# ! -------------------------------------------------------------------
# ? >> Miscellaneous initialization functionality

load "${REPOSITORY_ROOT}/test/helper/common"

# ? << Miscellaneous initialization functionality
# ! -------------------------------------------------------------------
# ? >> Negotiate TLS

# For certs actually provisioned from LetsEncrypt the Root CA cert should not need to be provided,
# as it would already be available by default in `/etc/ssl/certs`, requiring only the cert chain (fullchain.pem).
function _should_succesfully_negotiate_tls() {
  local FQDN=${1}
  # shellcheck disable=SC2031
  local CA_CERT=${2:-${TEST_CA_CERT}}

  # Postfix and Dovecot are ready:
  _wait_for_smtp_port_in_container_to_respond
  _wait_for_tcp_port_in_container 993

  # Root CA cert should be present in the container:
  _run_in_container_bash "[[ -f ${CA_CERT} ]]"
  assert_success

  local PORTS=(25 587 465 143 993)
  for PORT in "${PORTS[@]}"; do
    _negotiate_tls "${FQDN}" "${PORT}"
  done
}

# Basically runs commands like:
# docker exec "${TEST_NAME}" sh -c "timeout 1 openssl s_client -connect localhost:587 -starttls smtp -CAfile ${CA_CERT} 2>/dev/null | grep 'Verification'"
function _negotiate_tls() {
  local FQDN=${1}
  local PORT=${2}
  # shellcheck disable=SC2031
  local CA_CERT=${3:-${TEST_CA_CERT}}

  local CMD_OPENSSL_VERIFY
  CMD_OPENSSL_VERIFY=$(_generate_openssl_cmd "${PORT}")

  # Should fail as a chain of trust is required to verify successfully:
  run docker exec "${CONTAINER_NAME}" sh -c "${CMD_OPENSSL_VERIFY}"
  assert_output --partial 'Verification error: unable to verify the first certificate'

  # Provide the Root CA cert for successful verification:
  CMD_OPENSSL_VERIFY=$(_generate_openssl_cmd "${PORT}" "-CAfile ${CA_CERT}")
  run docker exec "${CONTAINER_NAME}" sh -c "${CMD_OPENSSL_VERIFY}"
  assert_output --partial 'Verification: OK'

  _should_support_fqdn_in_cert "${FQDN}" "${PORT}"
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
  if [[ ${PORT} =~ ^(25|587)$ ]]; then
    CMD_OPENSSL="${CMD_OPENSSL} -starttls smtp"
  elif [[ ${PORT} == 143 ]]; then
    CMD_OPENSSL="${CMD_OPENSSL} -starttls imap"
  elif [[ ${PORT} == 110 ]]; then
    CMD_OPENSSL="${CMD_OPENSSL} -starttls pop3"
  fi

  # `2>/dev/null` prevents openssl interleaving output to stderr that shouldn't be captured:
  echo "${CMD_OPENSSL} ${EXTRA_ARGS} 2>/dev/null"
}

# ? --------------------------------------------- Verify FQDN

function _get_fqdn_match_query() {
  local FQDN
  FQDN=$(_escape_fqdn "${1}")

  # 3rd check is for wildcard support by replacing the 1st DNS label of the FQDN with a `*`,
  # eg: `mail.example.test` will become `*.example.test` matching `DNS:*.example.test`.
  echo "Subject: CN = ${FQDN}|DNS:${FQDN}|DNS:\*\.${FQDN#*.}"
}

function _should_support_fqdn_in_cert() {
  _get_fqdns_for_cert "$@"
  assert_output --regexp "$(_get_fqdn_match_query "${1}")"
}

function _should_not_support_fqdn_in_cert() {
  _get_fqdns_for_cert "$@"
  refute_output --regexp "$(_get_fqdn_match_query "${1}")"
}

# Escapes `*` and `.` so the FQDN literal can be used in regex queries
# `sed` will match those two chars and `\\&` says to prepend a `\` to the sed match (`&`)
function _escape_fqdn() {
  # shellcheck disable=SC2001
  sed 's|[\*\.]|\\&|g' <<< "${1}"
}

function _get_fqdns_for_cert() {
  local FQDN=${1}
  local PORT=${2:-'25'}
  # shellcheck disable=SC2031
  local CA_CERT=${3:-${TEST_CA_CERT}}

  # `-servername` is for SNI, where the port may be for a service that serves multiple certs,
  # and needs a specific FQDN to return the correct cert. Such as a reverse-proxy.
  local EXTRA_ARGS="-servername ${FQDN} -CAfile ${CA_CERT}"
  local CMD_OPENSSL_VERIFY
  # eg: "timeout 1 openssl s_client -connect localhost:25 -starttls smtp ${EXTRA_ARGS} 2>/dev/null"
  CMD_OPENSSL_VERIFY=$(_generate_openssl_cmd "${PORT}" "${EXTRA_ARGS}")

  # Takes the result of the openssl output to return the x509 certificate,
  # We then check that for any matching FQDN entries:
  # main == `Subject CN = <FQDN>`, sans == `DNS:<FQDN>`
  local CMD_FILTER_FQDN="openssl x509 -noout -text | grep -E 'Subject: CN = |DNS:'"

  run docker exec "${CONTAINER_NAME}" sh -c "${CMD_OPENSSL_VERIFY} | ${CMD_FILTER_FQDN}"
}
