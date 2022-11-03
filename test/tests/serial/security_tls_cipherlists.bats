#!/usr/bin/env bats
load 'test_helper/common'
# Globals ${BATS_TMPDIR} and ${NAME}
# `${NAME}` defaults to `mailserver-testing:ci`

function teardown() {
  docker rm -f tls_test_cipherlists
}

function setup_file() {
  export DOMAIN="example.test"
  export NETWORK="test-network"

  # Shared config for TLS testing (read-only)
  export TLS_CONFIG_VOLUME
  TLS_CONFIG_VOLUME="$(pwd)/test/test-files/ssl/${DOMAIN}/:/config/ssl/:ro"
  # `${BATS_TMPDIR}` maps to `/tmp`
  export TLS_RESULTS_DIR="${BATS_TMPDIR}/results"

  # NOTE: If the network already exists, test will fail to start.
  docker network create "${NETWORK}"

  # Copies all of `./test/config/` to specific directory for testing
  # `${PRIVATE_CONFIG}` becomes `$(pwd)/test/duplicate_configs/<bats test filename>`
  export PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  # Pull `testssl.sh` image in advance to avoid it interfering with the `run` captured output.
  # Only interferes (potential test failure) with `assert_output` not `assert_success`?
  docker pull drwetter/testssl.sh:3.1dev
}

function teardown_file() {
  docker network rm "${NETWORK}"
}

@test "checking tls: cipher list - rsa intermediate" {
  check_ports 'rsa' 'intermediate'
}

@test "checking tls: cipher list - rsa modern" {
  check_ports 'rsa' 'modern'
}

@test "checking tls: cipher list - ecdsa intermediate" {
  check_ports 'ecdsa' 'intermediate'
}

@test "checking tls: cipher list - ecdsa modern" {
  check_ports 'ecdsa' 'modern'
}


# Only ECDSA with RSA fallback is tested.
# There isn't a situation where RSA with ECDSA fallback would make sense.
@test "checking tls: cipher list - ecdsa intermediate, with rsa fallback" {
  check_ports 'ecdsa' 'intermediate' 'rsa'
}

@test "checking tls: cipher list - ecdsa modern, with rsa fallback" {
  check_ports 'ecdsa' 'modern' 'rsa'
}

function check_ports() {
  local KEY_TYPE=$1
  local TLS_LEVEL=$2
  local ALT_KEY_TYPE=$3 # Optional parameter

  local KEY_TYPE_LABEL="${KEY_TYPE}"
  # This is just to add a `_` delimiter between the two key types for readability
  if [[ -n ${ALT_KEY_TYPE} ]]
  then
    KEY_TYPE_LABEL="${KEY_TYPE}_${ALT_KEY_TYPE}"
  fi
  local RESULTS_PATH="${KEY_TYPE_LABEL}/${TLS_LEVEL}"

  collect_cipherlist_data

  # SMTP: Opportunistic STARTTLS Explicit(25)
  # Needs to test against cipher lists specific to Port 25 ('_p25' parameter)
  check_cipherlists "${RESULTS_PATH}/port_25.json" '_p25'

  # SMTP Submission: Mandatory STARTTLS Explicit(587) and Implicit(465) TLS
  check_cipherlists "${RESULTS_PATH}/port_587.json"
  check_cipherlists "${RESULTS_PATH}/port_465.json"

  # IMAP: Mandatory STARTTLS Explicit(143) and Implicit(993) TLS
  check_cipherlists "${RESULTS_PATH}/port_143.json"
  check_cipherlists "${RESULTS_PATH}/port_993.json"

  # POP3: Mandatory STARTTLS Explicit(110) and Implicit(995)
  check_cipherlists "${RESULTS_PATH}/port_110.json"
  check_cipherlists "${RESULTS_PATH}/port_995.json"
}

function collect_cipherlist_data() {
  local ALT_CERT=()
  local ALT_KEY=()

  if [[ -n ${ALT_KEY_TYPE} ]]
  then
    ALT_CERT=(--env SSL_ALT_CERT_PATH="/config/ssl/cert.${ALT_KEY_TYPE}.pem")
    ALT_KEY=(--env SSL_ALT_KEY_PATH="/config/ssl/key.${ALT_KEY_TYPE}.pem")
  fi

  run docker run -d --name tls_test_cipherlists \
    --volume "${PRIVATE_CONFIG}/:/tmp/docker-mailserver/" \
    --volume "${TLS_CONFIG_VOLUME}" \
    --env ENABLE_POP3=1 \
    --env SSL_TYPE="manual" \
    --env SSL_CERT_PATH="/config/ssl/cert.${KEY_TYPE}.pem" \
    --env SSL_KEY_PATH="/config/ssl/key.${KEY_TYPE}.pem" \
    "${ALT_CERT[@]}" \
    "${ALT_KEY[@]}" \
    --env TLS_LEVEL="${TLS_LEVEL}" \
    --network "${NETWORK}" \
    --network-alias "${DOMAIN}" \
    --hostname "mail.${DOMAIN}" \
    --tty \
    "${NAME}" # Image name

  assert_success

  wait_for_tcp_port_in_container 25 tls_test_cipherlists
  # NOTE: An rDNS query for the container IP will resolve to `<container name>.<network name>.`

  # Make directory with test user ownership. Avoids Docker creating with root ownership.
  # TODO: Can switch to filename prefix for JSON output when this is resolved: https://github.com/drwetter/testssl.sh/issues/1845
  mkdir -p "${TLS_RESULTS_DIR}/${RESULTS_PATH}"

  # For non-CI test runs, instead of removing prior test files after this test suite completes,
  # they're retained and overwritten by future test runs instead. Useful for inspection.
  # `--preference` reduces the test scope to the cipher suites reported as supported by the server. Completes in ~35% of the time.
  local TESTSSL_CMD=(--quiet --file "/config/ssl/testssl.txt" --mode parallel --overwrite --preference)
  # NOTE: Batch testing ports via `--file` doesn't properly bubble up failure.
  # If the failure for a test is misleading consider testing a single port with:
  # local TESTSSL_CMD=(--quiet --jsonfile-pretty "${RESULTS_PATH}/port_${PORT}.json" --starttls smtp "${DOMAIN}:${PORT}")
  # TODO: Can use `jq` to check for failure when this is resolved: https://github.com/drwetter/testssl.sh/issues/1844

  # `--user "<uid>:<gid>"` is a workaround: Avoids `permission denied` write errors for json output, uses `id` to match user uid & gid.
  run docker run --rm \
    --user "$(id -u):$(id -g)" \
    --network "${NETWORK}" \
    --volume "${TLS_CONFIG_VOLUME}" \
    --volume "${TLS_RESULTS_DIR}/${RESULTS_PATH}/:/output" \
    --workdir "/output" \
    drwetter/testssl.sh:3.1dev "${TESTSSL_CMD[@]}"

  assert_success
}

# Use `jq` to extract a specific cipher list from the target`testssl.sh` results json output file
function compare_cipherlist() {
  local TARGET_CIPHERLIST=$1
  local RESULTS_FILE=$2
  local EXPECTED_CIPHERLIST=$3

  run jq '.scanResult[0].serverPreferences[] | select(.id=="'"${TARGET_CIPHERLIST}"'") | .finding' "${TLS_RESULTS_DIR}/${RESULTS_FILE}"
  assert_success
  assert_output "${EXPECTED_CIPHERLIST}"
}

# Compares the expected cipher lists against logged test results from `testssl.sh`
function check_cipherlists() {
  local RESULTS_FILE=$1
  local p25=$2 # optional suffix

  # TLS_LEVEL `modern` doesn't have TLS v1.0 or v1.1 cipher suites. Sets TLS v1.2 as minimum.
  if [[ ${TLS_LEVEL} == "intermediate" ]]
  then
    compare_cipherlist "cipherorder_TLSv1"   "${RESULTS_FILE}" "$(get_cipherlist "TLSv1${p25}")"
    compare_cipherlist "cipherorder_TLSv1_1" "${RESULTS_FILE}" "$(get_cipherlist "TLSv1_1${p25}")"
  fi

  compare_cipherlist "cipherorder_TLSv1_2" "${RESULTS_FILE}" "$(get_cipherlist "TLSv1_2${p25}")"
  compare_cipherlist "cipherorder_TLSv1_3" "${RESULTS_FILE}" "$(get_cipherlist 'TLSv1_3')"
}

# Expected cipher lists. Should match `TLS_LEVEL` cipher lists set in `start-mailserver.sh`.
# Excluding Port 25 which uses defaults from Postfix after applying `smtpd_tls_exclude_ciphers` rules.
# NOTE: If a test fails, look at the `check_ports` params, then update the corresponding associative key's value
# with the `actual` error value (assuming an update needs to be made, and not a valid security issue to look into).
function get_cipherlist() {
  local TLS_VERSION=$1

  if [[ ${TLS_VERSION} == "TLSv1_3" ]]
  then
    # TLS v1.3 cipher suites are not user defineable and not unique to the available certificate(s).
    # They do not support server enforced order either.
    echo '"TLS_AES_256_GCM_SHA384 TLS_CHACHA20_POLY1305_SHA256 TLS_AES_128_GCM_SHA256"'
  else
    # Associative array for easy querying of required cipher list
    declare -A CIPHER_LIST

    # `intermediate` cipher lists TLS v1.0 and v1.1 cipher suites should be the same:
    CIPHER_LIST["rsa_intermediate_TLSv1"]='"ECDHE-RSA-AES128-SHA ECDHE-RSA-AES256-SHA DHE-RSA-AES128-SHA DHE-RSA-AES256-SHA"'
    CIPHER_LIST["rsa_intermediate_TLSv1_1"]=${CIPHER_LIST["rsa_intermediate_TLSv1"]}
    CIPHER_LIST["rsa_intermediate_TLSv1_2"]='"ECDHE-RSA-CHACHA20-POLY1305 ECDHE-RSA-AES128-GCM-SHA256 ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-AES128-SHA256 ECDHE-RSA-AES256-SHA384 ECDHE-RSA-AES128-SHA ECDHE-RSA-AES256-SHA DHE-RSA-AES128-SHA256 DHE-RSA-AES128-SHA DHE-RSA-AES256-SHA256 DHE-RSA-AES256-SHA"'
    # `modern` cipher lists shouldn't have TLS v1.0 or v1.1 cipher suites:
    CIPHER_LIST["rsa_modern_TLSv1_2"]='"ECDHE-RSA-AES128-GCM-SHA256 ECDHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384"'

    # ECDSA:
    CIPHER_LIST["ecdsa_intermediate_TLSv1"]='"ECDHE-ECDSA-AES128-SHA ECDHE-ECDSA-AES256-SHA"'
    CIPHER_LIST["ecdsa_intermediate_TLSv1_1"]=${CIPHER_LIST["ecdsa_intermediate_TLSv1"]}
    CIPHER_LIST["ecdsa_intermediate_TLSv1_2"]='"ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-ECDSA-AES128-SHA256 ECDHE-ECDSA-AES128-SHA ECDHE-ECDSA-AES256-SHA384 ECDHE-ECDSA-AES256-SHA"'
    CIPHER_LIST["ecdsa_modern_TLSv1_2"]='"ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-ECDSA-CHACHA20-POLY1305"'

    # ECDSA + RSA fallback, dual cert support:
    CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1"]='"ECDHE-ECDSA-AES128-SHA ECDHE-RSA-AES128-SHA ECDHE-ECDSA-AES256-SHA ECDHE-RSA-AES256-SHA DHE-RSA-AES128-SHA DHE-RSA-AES256-SHA"'
    CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1_1"]=${CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1"]}
    CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1_2"]='"ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-RSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-RSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384 ECDHE-ECDSA-AES128-SHA256 ECDHE-RSA-AES128-SHA256 ECDHE-ECDSA-AES128-SHA ECDHE-RSA-AES256-SHA384 ECDHE-RSA-AES128-SHA ECDHE-ECDSA-AES256-SHA384 ECDHE-ECDSA-AES256-SHA ECDHE-RSA-AES256-SHA DHE-RSA-AES128-SHA256 DHE-RSA-AES128-SHA DHE-RSA-AES256-SHA256 DHE-RSA-AES256-SHA"'
    CIPHER_LIST["ecdsa_rsa_modern_TLSv1_2"]='"ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-RSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-RSA-AES256-GCM-SHA384 ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384"'


    # Port 25
    # TLSv1 and TLSv1_1 share the same cipher suites as other ports have. But the server order differs:
    CIPHER_LIST["rsa_intermediate_TLSv1_p25"]='"ECDHE-RSA-AES256-SHA DHE-RSA-AES256-SHA ECDHE-RSA-AES128-SHA DHE-RSA-AES128-SHA"'
    CIPHER_LIST["rsa_intermediate_TLSv1_1_p25"]=${CIPHER_LIST["rsa_intermediate_TLSv1_p25"]}
    # TLSv1_2 has different server order and also includes ARIA, CCM, DHE+CHACHA20-POLY1305 cipher suites:
    CIPHER_LIST["rsa_intermediate_TLSv1_2_p25"]='"ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-CHACHA20-POLY1305 DHE-RSA-AES256-CCM8 DHE-RSA-AES256-CCM ECDHE-ARIA256-GCM-SHA384 DHE-RSA-ARIA256-GCM-SHA384 ECDHE-RSA-AES256-SHA384 DHE-RSA-AES256-SHA256 ECDHE-RSA-AES256-SHA DHE-RSA-AES256-SHA ARIA256-GCM-SHA384 ECDHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-CCM8 DHE-RSA-AES128-CCM ECDHE-ARIA128-GCM-SHA256 DHE-RSA-ARIA128-GCM-SHA256 ECDHE-RSA-AES128-SHA256 DHE-RSA-AES128-SHA256 ECDHE-RSA-AES128-SHA DHE-RSA-AES128-SHA ARIA128-GCM-SHA256"'
    # Port 25 is unaffected by `TLS_LEVEL` profiles (other than min TLS version), it has the same TLS v1.2 cipher list under both:
    CIPHER_LIST["rsa_modern_TLSv1_2_p25"]=${CIPHER_LIST["rsa_intermediate_TLSv1_2_p25"]}

    # ECDSA (Port 25):
    CIPHER_LIST["ecdsa_intermediate_TLSv1_p25"]='"ECDHE-ECDSA-AES256-SHA ECDHE-ECDSA-AES128-SHA"'
    CIPHER_LIST["ecdsa_intermediate_TLSv1_1_p25"]=${CIPHER_LIST["ecdsa_intermediate_TLSv1_p25"]}

    CIPHER_LIST["ecdsa_intermediate_TLSv1_2_p25"]='"ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES256-CCM8 ECDHE-ECDSA-AES256-CCM ECDHE-ECDSA-ARIA256-GCM-SHA384 ECDHE-ECDSA-AES256-SHA384 ECDHE-ECDSA-AES256-SHA ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES128-CCM8 ECDHE-ECDSA-AES128-CCM ECDHE-ECDSA-ARIA128-GCM-SHA256 ECDHE-ECDSA-AES128-SHA256 ECDHE-ECDSA-AES128-SHA"'
    CIPHER_LIST["ecdsa_modern_TLSv1_2_p25"]=${CIPHER_LIST["ecdsa_intermediate_TLSv1_2_p25"]}


    # ECDSA + RSA fallback, dual cert support (Port 25):
    CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1_p25"]='"ECDHE-ECDSA-AES256-SHA ECDHE-RSA-AES256-SHA DHE-RSA-AES256-SHA ECDHE-ECDSA-AES128-SHA ECDHE-RSA-AES128-SHA DHE-RSA-AES128-SHA"'
    CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1_1_p25"]=${CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1_p25"]}

    CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1_2_p25"]='"ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES256-GCM-SHA384 ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES256-CCM8 ECDHE-ECDSA-AES256-CCM DHE-RSA-AES256-CCM8 DHE-RSA-AES256-CCM ECDHE-ECDSA-ARIA256-GCM-SHA384 ECDHE-ARIA256-GCM-SHA384 DHE-RSA-ARIA256-GCM-SHA384 ECDHE-ECDSA-AES256-SHA384 ECDHE-RSA-AES256-SHA384 DHE-RSA-AES256-SHA256 ECDHE-ECDSA-AES256-SHA ECDHE-RSA-AES256-SHA DHE-RSA-AES256-SHA ARIA256-GCM-SHA384 ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES128-CCM8 ECDHE-ECDSA-AES128-CCM DHE-RSA-AES128-CCM8 DHE-RSA-AES128-CCM ECDHE-ECDSA-ARIA128-GCM-SHA256 ECDHE-ARIA128-GCM-SHA256 DHE-RSA-ARIA128-GCM-SHA256 ECDHE-ECDSA-AES128-SHA256 ECDHE-RSA-AES128-SHA256 DHE-RSA-AES128-SHA256 ECDHE-ECDSA-AES128-SHA ECDHE-RSA-AES128-SHA DHE-RSA-AES128-SHA ARIA128-GCM-SHA256"'
    CIPHER_LIST["ecdsa_rsa_modern_TLSv1_2_p25"]=${CIPHER_LIST["ecdsa_rsa_intermediate_TLSv1_2_p25"]}


    local TARGET_QUERY="${KEY_TYPE_LABEL}_${TLS_LEVEL}_${TLS_VERSION}"
    echo "${CIPHER_LIST[${TARGET_QUERY}]}"
  fi
}
