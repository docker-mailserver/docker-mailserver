#!/usr/bin/env bats
load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    # Internal copies made by `start-mailserver.sh`:
    export PRIMARY_KEY='/etc/dms/tls/key'
    export PRIMARY_CERT='/etc/dms/tls/cert'
    export FALLBACK_KEY='/etc/dms/tls/fallback_key'
    export FALLBACK_CERT='/etc/dms/tls/fallback_cert'

    # Volume mounted certs:
    export SSL_KEY_PATH='/config/ssl/key.ecdsa.pem'
    export SSL_CERT_PATH='/config/ssl/cert.ecdsa.pem'
    export SSL_ALT_KEY_PATH='/config/ssl/key.rsa.pem'
    export SSL_ALT_CERT_PATH='/config/ssl/cert.rsa.pem'

    local DOMAIN='example.test'
    local PRIVATE_CONFIG
    PRIVATE_CONFIG="$(duplicate_config_for_container .)"

    docker run -d --name mail_manual_ssl \
        --volume "${PRIVATE_CONFIG}/:/tmp/docker-mailserver/" \
        --volume "$(pwd)/test/test-files/ssl/${DOMAIN}/with_ca/ecdsa/:/config/ssl/" \
        --env DMS_DEBUG=0 \
        --env SSL_TYPE='manual' \
        --env TLS_LEVEL='modern' \
        --env SSL_KEY_PATH="${SSL_KEY_PATH}" \
        --env SSL_CERT_PATH="${SSL_CERT_PATH}" \
        --env SSL_ALT_KEY_PATH="${SSL_ALT_KEY_PATH}" \
        --env SSL_ALT_CERT_PATH="${SSL_ALT_CERT_PATH}" \
        --hostname "mail.${DOMAIN}" \
        --tty \
        "${NAME}" # Image name
    wait_for_finished_setup_in_container mail_manual_ssl
}

function teardown_file() {
    docker rm -f mail_manual_ssl
}

@test "first" {
    skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking ssl: ENV vars provided are valid files" {
    assert docker exec mail_manual_ssl [ -f "${SSL_CERT_PATH}" ]
    assert docker exec mail_manual_ssl [ -f "${SSL_KEY_PATH}" ]
    assert docker exec mail_manual_ssl [ -f "${SSL_ALT_CERT_PATH}" ]
    assert docker exec mail_manual_ssl [ -f "${SSL_ALT_KEY_PATH}" ]
}

@test "checking ssl: manual configuration is correct" {
    local DOVECOT_CONFIG_SSL='/etc/dovecot/conf.d/10-ssl.conf'

    run docker exec mail_manual_ssl grep '^smtpd_tls_chain_files =' '/etc/postfix/main.cf'
    assert_success
    assert_output "smtpd_tls_chain_files = ${PRIMARY_KEY} ${PRIMARY_CERT} ${FALLBACK_KEY} ${FALLBACK_CERT}"

    run docker exec mail_manual_ssl grep '^ssl_key =' "${DOVECOT_CONFIG_SSL}"
    assert_success
    assert_output "ssl_key = <${PRIMARY_KEY}"

    run docker exec mail_manual_ssl grep '^ssl_cert =' "${DOVECOT_CONFIG_SSL}"
    assert_success
    assert_output "ssl_cert = <${PRIMARY_CERT}"

    run docker exec mail_manual_ssl grep '^ssl_alt_key =' "${DOVECOT_CONFIG_SSL}"
    assert_success
    assert_output "ssl_alt_key = <${FALLBACK_KEY}"

    run docker exec mail_manual_ssl grep '^ssl_alt_cert =' "${DOVECOT_CONFIG_SSL}"
    assert_success
    assert_output "ssl_alt_cert = <${FALLBACK_CERT}"
}

@test "checking ssl: manual configuration copied files correctly " {
    run docker exec mail_manual_ssl cmp -s "${PRIMARY_KEY}" "${SSL_KEY_PATH}"
    assert_success
    run docker exec mail_manual_ssl cmp -s "${PRIMARY_CERT}" "${SSL_CERT_PATH}"
    assert_success

    # Fallback cert
    run docker exec mail_manual_ssl cmp -s "${FALLBACK_KEY}" "${SSL_ALT_KEY_PATH}"
    assert_success
    run docker exec mail_manual_ssl cmp -s "${FALLBACK_CERT}" "${SSL_ALT_CERT_PATH}"
    assert_success
}

@test "checking ssl: manual cert works correctly" {
    wait_for_tcp_port_in_container 587 mail_manual_ssl
    local TEST_COMMAND=(timeout 1 openssl s_client -connect mail.example.test:587 -starttls smtp)
    local RESULT

    # Should fail as a chain of trust is required to verify successfully:
    RESULT=$(docker exec mail_manual_ssl "${TEST_COMMAND[@]}" | grep 'Verification error:')
    assert_equal "${RESULT}" 'Verification error: unable to verify the first certificate'

    # Provide the Root CA cert for successful verification:
    local CA_CERT='/config/ssl/ca-cert.ecdsa.pem'
    assert docker exec mail_manual_ssl [ -f "${CA_CERT}" ]
    RESULT=$(docker exec mail_manual_ssl "${TEST_COMMAND[@]}" -CAfile "${CA_CERT}" | grep 'Verification: OK')
    assert_equal "${RESULT}" 'Verification: OK'
}

@test "checking ssl: manual cert changes are picked up by check-for-changes" {
    docker exec mail_manual_ssl /bin/bash -c 'printf "changed" >>${SSL_KEY_PATH}'
    sleep 10

    run docker exec mail_manual_ssl /bin/bash -c "supervisorctl tail -3000 changedetector"
    assert_output --partial 'postfix: stopped'
    assert_output --partial 'postfix: started'
    assert_output --partial 'Change detected'
}

@test "last" {
    skip 'this test is only there to reliably mark the end for the teardown_file'
}
