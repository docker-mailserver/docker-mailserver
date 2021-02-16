load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    export KEY_TYPE="rsa"
    export TLS_LEVEL="intermediate"
    export DOMAIN="example.test"
    export NETWORK="test-network"

    # Shared config for TLS testing (read-only)
    export TLS_CONFIG_VOLUME
    TLS_CONFIG_VOLUME="$(pwd)/test/test-files/ssl/${DOMAIN}/:/config/ssl/:ro"
    # `${BATS_TMPDIR}` maps to `/tmp`
    export TLS_RESULTS_DIR="${BATS_TMPDIR}/results"

    # If the directory or network already exist, test will fail to start
    mkdir "${TLS_RESULTS_DIR}"
    docker network create "${NETWORK}"

    # Copies all of `./test/config/` to specific directory for testing
    # `${PRIVATE_CONFIG}` becomes `$(pwd)/test/duplicate_configs/<bats test filename>`
    local PRIVATE_CONFIG
    PRIVATE_CONFIG="$(duplicate_config_for_container .)"

    docker run -d --name tls_test_cipherlists \
        --volume "${PRIVATE_CONFIG}/:/tmp/docker-mailserver/" \
        --volume "${TLS_CONFIG_VOLUME}" \
        --env DMS_DEBUG=0 \
        --env ENABLE_POP3=1 \
        --env SSL_TYPE="manual" \
        --env SSL_CERT_PATH="/config/ssl/cert.${KEY_TYPE}.pem" \
        --env SSL_KEY_PATH="/config/ssl/key.${KEY_TYPE}.pem" \
        --env TLS_LEVEL="${TLS_LEVEL}" \
        --network "${NETWORK}" \
        --network-alias "${DOMAIN}" \
        --hostname "mail.${DOMAIN}" \
        --tty \
        "${NAME}" # Image name
    # `${NAME}` defaults to `mailserver-testing:ci`
    wait_for_finished_setup_in_container tls_test_cipherlists
    # NOTE: An rDNS query for the container IP will resolve to `<container name>.<network name>.`
}

function teardown_file() {
    docker rm -f tls_test_cipherlists
    docker network rm "${NETWORK}"
    rm -rf "${TLS_RESULTS_DIR}"
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking tls: cipher list configuration is correct for port 25" {
    local PORT=25
    local RESULTS_FILE="port_${PORT}.json"
    local RESULTS_PATH="${KEY_TYPE}/${TLS_LEVEL}"
    local RESULTS_FILEPATH="${RESULTS_PATH}/${RESULTS_FILE}"

    # `--user "0:0"` is a workaround: Avoids `permission denied` write errors for results when directory is owned by root
    run docker run --rm \
        --user "0:0" \
        --network "${NETWORK}" \
        --volume "${TLS_CONFIG_VOLUME}" \
        --volume "${TLS_RESULTS_DIR}/${RESULTS_PATH}/:/output" \
        --workdir "/output" \
        drwetter/testssl.sh:3.1dev --quiet --jsonfile-pretty "${RESULTS_FILE}" --starttls smtp "${DOMAIN}:${PORT}"
    assert_success

    local CIPHERLIST_RSA_INTERMEDIATE_TLSv1_1='"ECDHE-RSA-AES256-SHA DHE-RSA-AES256-SHA ECDHE-RSA-AES128-SHA DHE-RSA-AES128-SHA"'
    compare_cipherlist "cipherorder_TLSv1" "${RESULTS_FILEPATH}" "${CIPHERLIST_RSA_INTERMEDIATE_TLSv1_1}"
    compare_cipherlist "cipherorder_TLSv1_1" "${RESULTS_FILEPATH}" "${CIPHERLIST_RSA_INTERMEDIATE_TLSv1_1}"

    local CIPHERLIST_RSA_INTERMEDIATE_TLSv1_2='"ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-CHACHA20-POLY1305 DHE-RSA-CHACHA20-POLY1305 DHE-RSA-AES256-CCM8 DHE-RSA-AES256-CCM ECDHE-ARIA256-GCM-SHA384 DHE-RSA-ARIA256-GCM-SHA384 ECDHE-RSA-AES256-SHA384 DHE-RSA-AES256-SHA256 ECDHE-RSA-AES256-SHA DHE-RSA-AES256-SHA ARIA256-GCM-SHA384 ECDHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-CCM8 DHE-RSA-AES128-CCM ECDHE-ARIA128-GCM-SHA256 DHE-RSA-ARIA128-GCM-SHA256 ECDHE-RSA-AES128-SHA256 DHE-RSA-AES128-SHA256 ECDHE-RSA-AES128-SHA DHE-RSA-AES128-SHA ARIA128-GCM-SHA256"'
    compare_cipherlist "cipherorder_TLSv1_2" "${RESULTS_FILEPATH}" "${CIPHERLIST_RSA_INTERMEDIATE_TLSv1_2}"

    local CIPHERLIST_TLSv1_3='"TLS_AES_256_GCM_SHA384 TLS_CHACHA20_POLY1305_SHA256 TLS_AES_128_GCM_SHA256"'
    compare_cipherlist "cipherorder_TLSv1_3" "${RESULTS_FILEPATH}" "${CIPHERLIST_TLSv1_3}"
}

@test "checking tls: cipher list configuration is correct for ports 587, 465, 143, 993, 110, 995" {
    local RESULTS_PATH="${KEY_TYPE}/${TLS_LEVEL}"

    run docker run --rm \
        --user "0:0" \
        --network "${NETWORK}" \
        --volume "${TLS_CONFIG_VOLUME}" \
        --volume "${TLS_RESULTS_DIR}/${RESULTS_PATH}/:/output" \
        --workdir "/output" \
        drwetter/testssl.sh:3.1dev --file /config/ssl/testssl.txt --mode parallel
    assert_success

    # Explicit(587) and Implicit(465) TLS
    check_cipherlists "${RESULTS_PATH}/port_587.json"
    check_cipherlists "${RESULTS_PATH}/port_465.json"
    # IMAP Explicit(143) and Implicit(993) TLS
    check_cipherlists "${RESULTS_PATH}/port_143.json"
    check_cipherlists "${RESULTS_PATH}/port_993.json"
    # POP3 Explicit(110) and Implicit(995)
    check_cipherlists "${RESULTS_PATH}/port_110.json"
    check_cipherlists "${RESULTS_PATH}/port_995.json"
}

# Use `jq` to extract a specific cipher list from the target`testssl.sh` results json output file
function compare_cipherlist() {
    local TARGET_CIPHERLIST=$1
    local RESULTS_FILE=$2
    local EXPECTED_CIPHERLIST=$3

    run docker run --rm \
        --volume "${TLS_RESULTS_DIR}:/input" \
        --workdir "/input" \
        dwdraju/alpine-curl-jq jq '.scanResult[0].fs[] | select(.id=="'"${TARGET_CIPHERLIST}"'") | .finding' "${RESULTS_FILE}"
    assert_success
    assert_output "${EXPECTED_CIPHERLIST}"
}

# Compares the expected cipher lists against logged test results from `testssl.sh`
function check_cipherlists() {
    local RESULTS_FILE=$1

    compare_cipherlist "cipherorder_TLSv1"   "${RESULTS_FILE}" "$(get_cipherlist 'TLSv1')"
    compare_cipherlist "cipherorder_TLSv1_1" "${RESULTS_FILE}" "$(get_cipherlist 'TLSv1_1')"
    compare_cipherlist "cipherorder_TLSv1_2" "${RESULTS_FILE}" "$(get_cipherlist 'TLSv1_2')"
    compare_cipherlist "cipherorder_TLSv1_3" "${RESULTS_FILE}" "$(get_cipherlist 'TLSv1_3')"
}

# Expected cipher lists. Should match `TLS_LEVEL` cipher lists set in `start-mailserver.sh`.
# Excluding Port 25 which uses defaults from Postfix after applying `smtpd_tls_exclude_ciphers` rules.
function get_cipherlist() {
    local TLS_VERSION=$1

    if [[ "${TLS_VERSION}" == "TLSv1_3" ]]
        then
            # TLS v1.3 cipher suites are not user defineable and not unique to the available certificate(s).
            # They do not support server enforced order either.
            echo '"TLS_AES_256_GCM_SHA384 TLS_CHACHA20_POLY1305_SHA256 TLS_AES_128_GCM_SHA256"'
        else

        # Associative array for easy querying of required cipher list
        declare -A CIPHER_LIST
        # Our TLS v1.0 and v1.1 cipher suites should be the same:
        CIPHER_LIST["rsa_intermediate_TLSv1"]='"ECDHE-RSA-AES128-SHA ECDHE-RSA-AES256-SHA DHE-RSA-AES128-SHA DHE-RSA-AES256-SHA"'
        CIPHER_LIST["rsa_intermediate_TLSv1_1"]=${CIPHER_LIST["rsa_intermediate_TLSv1"]}
        CIPHER_LIST["rsa_intermediate_TLSv1_2"]='"ECDHE-RSA-CHACHA20-POLY1305 ECDHE-RSA-AES128-GCM-SHA256 ECDHE-RSA-AES256-GCM-SHA384 DHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-AES128-SHA256 ECDHE-RSA-AES256-SHA384 ECDHE-RSA-AES128-SHA ECDHE-RSA-AES256-SHA DHE-RSA-AES128-SHA256 DHE-RSA-AES128-SHA DHE-RSA-AES256-SHA256 DHE-RSA-AES256-SHA"'

        local TARGET_QUERY="${KEY_TYPE}_${TLS_LEVEL}_${TLS_VERSION}"
        echo "${CIPHER_LIST[${TARGET_QUERY}]}"
    fi
}

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
