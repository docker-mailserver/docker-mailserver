load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Security] (TLS) (cipher lists) '
CONTAINER_PREFIX='dms-test_tls-cipherlists'

# NOTE: Tests cases here cannot be run concurrently:
# - The `testssl.txt` file configures `testssl.sh` to connect to `example.test` (TEST_DOMAIN)
#   and this is set as a network alias to the DMS container being tested.
# - If multiple containers are active with this alias, the connection is not deterministic and will result
#   in comparing the wrong results for a given variant.

function setup_file() {
  export TEST_DOMAIN='example.test'
  export TEST_FQDN="mail.${TEST_DOMAIN}"
  export TEST_NETWORK='test-network'

  # Contains various certs for testing TLS support (read-only):
  export TLS_CONFIG_VOLUME
  TLS_CONFIG_VOLUME="${PWD}/test/test-files/ssl/${TEST_DOMAIN}/:/config/ssl/:ro"

  # Used for connecting testssl and DMS containers via network name `TEST_DOMAIN`:
  # NOTE: If the network already exists, the test will fail to start
  docker network create "${TEST_NETWORK}"

  # Pull `testssl.sh` image in advance to avoid it interfering with the `run` captured output.
  # Only interferes (potential test failure) with `assert_output` not `assert_success`?
  docker pull drwetter/testssl.sh:3.2

  # Only used in `_should_support_expected_cipherlists()` to set a storage location for `testssl.sh` JSON output:
  # `${BATS_TMPDIR}` maps to `/tmp`: https://bats-core.readthedocs.io/en/v1.8.2/writing-tests.html#special-variables
  export TLS_RESULTS_DIR="${BATS_TMPDIR}/results"
}

function teardown_file() {
  docker network rm "${TEST_NETWORK}"
}

function teardown() { _default_teardown ; }

@test "'TLS_LEVEL=intermediate' + RSA" {
  _configure_and_run_dms_container 'intermediate' 'rsa'
  _should_support_expected_cipherlists
}

@test "'TLS_LEVEL=intermediate' + ECDSA" {
  _configure_and_run_dms_container 'intermediate' 'ecdsa'
  _should_support_expected_cipherlists
}

# Only ECDSA with an RSA fallback is tested.
# There isn't a situation where RSA with an ECDSA fallback would make sense.
@test "'TLS_LEVEL=intermediate' + ECDSA with RSA fallback" {
  _configure_and_run_dms_container 'intermediate' 'ecdsa' 'rsa'
  _should_support_expected_cipherlists
}

@test "'TLS_LEVEL=modern' + RSA" {
  _configure_and_run_dms_container 'modern' 'rsa'
  _should_support_expected_cipherlists
}

@test "'TLS_LEVEL=modern' + ECDSA" {
  _configure_and_run_dms_container 'modern' 'ecdsa'
  _should_support_expected_cipherlists
}

@test "'TLS_LEVEL=modern' + ECDSA with RSA fallback" {
  _configure_and_run_dms_container 'modern' 'ecdsa' 'rsa'
  _should_support_expected_cipherlists
}

function _configure_and_run_dms_container() {
  local TLS_LEVEL=$1
  local KEY_TYPE=$2
  local ALT_KEY_TYPE=$3 # Optional parameter

  export TEST_VARIANT="${TLS_LEVEL}-${KEY_TYPE}"
  if [[ -n ${ALT_KEY_TYPE} ]]; then
    TEST_VARIANT+="-${ALT_KEY_TYPE}"
  fi

  export CONTAINER_NAME="${CONTAINER_PREFIX}_${TEST_VARIANT}"
  # The initial set of args is static across test cases:
  local CUSTOM_SETUP_ARGUMENTS=(
    --volume "${TLS_CONFIG_VOLUME}"
    --network "${TEST_NETWORK}"
    --network-alias "${TEST_DOMAIN}"
    --env ENABLE_POP3=1
    --env SSL_TYPE="manual"
  )

  # The remaining args are dependent upon test case vars:
  CUSTOM_SETUP_ARGUMENTS+=(
    --env TLS_LEVEL="${TLS_LEVEL}"
    --env SSL_CERT_PATH="/config/ssl/with_ca/ecdsa/cert.${KEY_TYPE}.pem"
    --env SSL_KEY_PATH="/config/ssl/with_ca/ecdsa/key.${KEY_TYPE}.pem"
  )

  if [[ -n ${ALT_KEY_TYPE} ]]; then
    CUSTOM_SETUP_ARGUMENTS+=(
      --env SSL_ALT_CERT_PATH="/config/ssl/with_ca/ecdsa/cert.${ALT_KEY_TYPE}.pem"
      --env SSL_ALT_KEY_PATH="/config/ssl/with_ca/ecdsa/key.${ALT_KEY_TYPE}.pem"
    )
  fi

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container
}

function _should_support_expected_cipherlists() {
  # Make a directory with test user ownership. Avoids Docker creating this with root ownership.
  # TODO: Can switch to filename prefix for JSON output when this is resolved: https://github.com/drwetter/testssl.sh/issues/1845
  local RESULTS_PATH="${TLS_RESULTS_DIR}/${TEST_VARIANT}"
  mkdir -p "${RESULTS_PATH}"

  _collect_cipherlists
  _verify_cipherlists
}

# Verify that the collected results match our expected cipherlists:
function _verify_cipherlists() {
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

# Using `testssl.sh` we can test each port to collect a list of supported cipher suites (ordered):
function _collect_cipherlists() {
  # NOTE: An rDNS query for the container IP will resolve to `<container name>.<network name>.`

  # For non-CI test runs, instead of removing prior test files after this test suite completes,
  # they're retained and overwritten by future test runs instead. Useful for inspection.
  # `--preference` reduces the test scope to the cipher suites reported as supported by the server. Completes in ~35% of the time.
  local TESTSSL_CMD=(
    --quiet
    --file "/config/ssl/testssl.txt"
    --mode parallel
    --overwrite
    --preference
    --openssl /usr/bin/openssl
  )
  # NOTE: Batch testing ports via `--file` doesn't properly bubble up failure.
  # If the failure for a test is misleading consider testing a single port with:
  # local TESTSSL_CMD=(--quiet --jsonfile-pretty "/output/port_${PORT}.json" --starttls smtp "${TEST_DOMAIN}:${PORT}")
  # TODO: Can use `jq` to check for failure when this is resolved: https://github.com/drwetter/testssl.sh/issues/1844

  # `--user "<uid>:<gid>"` is a workaround: Avoids `permission denied` write errors for json output, uses `id` to match user uid & gid.
  run docker run --rm \
    --env ADDTL_CA_FILES="/config/ssl/with_ca/ecdsa/ca-cert.ecdsa.pem" \
    --user "$(id -u):$(id -g)" \
    --network "${TEST_NETWORK}" \
    --volume "${TLS_CONFIG_VOLUME}" \
    --volume "${RESULTS_PATH}:/output" \
    --workdir "/output" \
    drwetter/testssl.sh:3.2 "${TESTSSL_CMD[@]}"

  assert_success
}

# Compares the expected cipher lists against logged test results from `testssl.sh`
function check_cipherlists() {
  local RESULTS_FILEPATH=$1
  local p25=$2 # optional suffix

  compare_cipherlist "cipherorder_TLSv1_2" "$(get_cipherlist "TLSv1_2${p25}")"
  compare_cipherlist "cipherorder_TLSv1_3" "$(get_cipherlist 'TLSv1_3')"
}

# Use `jq` to extract a specific cipher list from the target`testssl.sh` results json output file
function compare_cipherlist() {
  local TARGET_CIPHERLIST=$1
  local EXPECTED_CIPHERLIST=$2

  run jq '.scanResult[0].serverPreferences[] | select(.id=="'"${TARGET_CIPHERLIST}"'") | .finding' "${RESULTS_FILEPATH}"
  assert_success
  assert_output "${EXPECTED_CIPHERLIST}"
}

# Expected cipher lists. Should match `TLS_LEVEL` cipher lists set in `scripts/helpers/ssl.sh`.
# Excluding Port 25 which uses defaults from Postfix after applying `smtpd_tls_exclude_ciphers` rules.
# NOTE: If a test fails, look at the `check_ports` params, then update the corresponding associative key's value
# with the `actual` error value (assuming an update needs to be made, and not a valid security issue to look into).
function get_cipherlist() {
  local TLS_VERSION=$1

  if [[ ${TLS_VERSION} == "TLSv1_3" ]]; then
    # TLS v1.3 cipher suites are not user defineable and not unique to the available certificate(s).
    # They do not support server enforced order either.
    echo '"TLS_AES_256_GCM_SHA384 TLS_CHACHA20_POLY1305_SHA256 TLS_AES_128_GCM_SHA256"'
  else
    # Associative array for easy querying of required cipher list
    declare -A CIPHER_LIST

    # RSA:
    CIPHER_LIST["intermediate-rsa_TLSv1_2"]='"ECDHE-RSA-CHACHA20-POLY1305 ECDHE-RSA-AES128-GCM-SHA256 ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-AES128-SHA256 ECDHE-RSA-AES256-SHA384 DHE-RSA-AES128-SHA256 DHE-RSA-AES256-SHA256"'
    CIPHER_LIST["modern-rsa_TLSv1_2"]='"ECDHE-RSA-AES128-GCM-SHA256 ECDHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384"'

    # ECDSA:
    CIPHER_LIST["intermediate-ecdsa_TLSv1_2"]='"ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-ECDSA-AES128-SHA256 ECDHE-ECDSA-AES256-SHA384"'
    CIPHER_LIST["modern-ecdsa_TLSv1_2"]='"ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-ECDSA-CHACHA20-POLY1305"'

    # ECDSA + RSA fallback, dual cert support:
    CIPHER_LIST["intermediate-ecdsa-rsa_TLSv1_2"]='"ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-RSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-RSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384 ECDHE-ECDSA-AES128-SHA256 ECDHE-RSA-AES128-SHA256 ECDHE-RSA-AES256-SHA384 ECDHE-ECDSA-AES256-SHA384 DHE-RSA-AES128-SHA256 DHE-RSA-AES256-SHA256"'
    CIPHER_LIST["modern-ecdsa-rsa_TLSv1_2"]='"ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-RSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-RSA-AES256-GCM-SHA384 ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384"'


    # Port 25 has a different server order, and also includes ARIA, CCM, DHE+CHACHA20-POLY1305 cipher suites:
    # RSA (Port 25):
    CIPHER_LIST["intermediate-rsa_TLSv1_2_p25"]='"ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-CHACHA20-POLY1305 DHE-RSA-AES256-CCM8 DHE-RSA-AES256-CCM ECDHE-ARIA256-GCM-SHA384 DHE-RSA-ARIA256-GCM-SHA384 ECDHE-RSA-AES256-SHA384 DHE-RSA-AES256-SHA256 ARIA256-GCM-SHA384 ECDHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-CCM8 DHE-RSA-AES128-CCM ECDHE-ARIA128-GCM-SHA256 DHE-RSA-ARIA128-GCM-SHA256 ECDHE-RSA-AES128-SHA256 DHE-RSA-AES128-SHA256 ARIA128-GCM-SHA256"'
    # ECDSA (Port 25):
    CIPHER_LIST["intermediate-ecdsa_TLSv1_2_p25"]='"ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES256-CCM8 ECDHE-ECDSA-AES256-CCM ECDHE-ECDSA-ARIA256-GCM-SHA384 ECDHE-ECDSA-AES256-SHA384 ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES128-CCM8 ECDHE-ECDSA-AES128-CCM ECDHE-ECDSA-ARIA128-GCM-SHA256 ECDHE-ECDSA-AES128-SHA256"'
    # ECDSA + RSA fallback, dual cert support (Port 25):
    CIPHER_LIST["intermediate-ecdsa-rsa_TLSv1_2_p25"]='"ECDHE-ECDSA-AES256-GCM-SHA384 ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES256-GCM-SHA384 ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES256-CCM8 ECDHE-ECDSA-AES256-CCM DHE-RSA-AES256-CCM8 DHE-RSA-AES256-CCM ECDHE-ECDSA-ARIA256-GCM-SHA384 ECDHE-ARIA256-GCM-SHA384 DHE-RSA-ARIA256-GCM-SHA384 ECDHE-ECDSA-AES256-SHA384 ECDHE-RSA-AES256-SHA384 DHE-RSA-AES256-SHA256 ARIA256-GCM-SHA384 ECDHE-ECDSA-AES128-GCM-SHA256 ECDHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-GCM-SHA256 ECDHE-ECDSA-AES128-CCM8 ECDHE-ECDSA-AES128-CCM DHE-RSA-AES128-CCM8 DHE-RSA-AES128-CCM ECDHE-ECDSA-ARIA128-GCM-SHA256 ECDHE-ARIA128-GCM-SHA256 DHE-RSA-ARIA128-GCM-SHA256 ECDHE-ECDSA-AES128-SHA256 ECDHE-RSA-AES128-SHA256 DHE-RSA-AES128-SHA256 ARIA128-GCM-SHA256"'

    # Port 25 is unaffected by `TLS_LEVEL` profiles, thus no difference for modern:
    CIPHER_LIST["modern-rsa_TLSv1_2_p25"]=${CIPHER_LIST["intermediate-rsa_TLSv1_2_p25"]}
    CIPHER_LIST["modern-ecdsa_TLSv1_2_p25"]=${CIPHER_LIST["intermediate-ecdsa_TLSv1_2_p25"]}
    CIPHER_LIST["modern-ecdsa-rsa_TLSv1_2_p25"]=${CIPHER_LIST["intermediate-ecdsa-rsa_TLSv1_2_p25"]}

    local TARGET_QUERY="${TEST_VARIANT}_${TLS_VERSION}"
    echo "${CIPHER_LIST[${TARGET_QUERY}]}"
  fi
}
