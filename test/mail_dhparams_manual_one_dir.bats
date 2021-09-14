load 'test_helper/common'

# Test case
# ---------
# By default, this image is using audited FFDHE groups (https://github.com/docker-mailserver/docker-mailserver/pull/1463)
#
# This test case covers the described case when `ONE_DIR=1`.
#
# Description:
# - When custom DHE parameters are supplied by the user:
#   1. User supplied DHE parameters are copied to the configuration directories for postfix and dovecot.
#   2. A warning is raised about usage of potentially insecure parameters.

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    local PRIVATE_CONFIG
    PRIVATE_CONFIG="$(duplicate_config_for_container .)"

    docker run -d --name mail_manual_dhparams_one_dir \
        -v "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
        -v "$(pwd)/test/test-files:/tmp/docker-mailserver-test:ro" \
        -v "$(pwd)/test/test-files/ssl/custom-dhe-params.pem:/var/mail-state/lib-shared/dhparams.pem:ro" \
        -e DMS_DEBUG=0 \
        -e ONE_DIR=1 \
        -h mail.my-domain.com \
        --tty \
        "${NAME}"

    wait_for_finished_setup_in_container mail_manual_dhparams_one_dir
}

function teardown_file() {
    docker rm -f mail_manual_dhparams_one_dir
}

@test "first" {
    skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking dhparams: ONE_DIR=1 check manual dhparams is used" {
    test_checksum=$(sha512sum "$(pwd)/test/test-files/ssl/custom-dhe-params.pem" | awk '{print $1}')
    run echo "${test_checksum}"
    refute_output '' # checksum must not be empty

    docker_dovecot_checksum=$(docker exec mail_manual_dhparams_one_dir sha512sum /etc/dovecot/dh.pem | awk '{print $1}')
    docker_postfix_checksum=$(docker exec mail_manual_dhparams_one_dir sha512sum /etc/postfix/dhparams.pem | awk '{print $1}')
    assert_equal "${docker_dovecot_checksum}" "${test_checksum}"
    assert_equal "${docker_postfix_checksum}" "${test_checksum}"
}

@test "checking dhparams: ONE_DIR=1 check warning output when using manual dhparams" {
    run sh -c "docker logs mail_manual_dhparams_one_dir | grep 'Using self-generated dhparams is considered insecure.'"
    assert_success
}

@test "last" {
    skip 'this test is only there to reliably mark the end for the teardown_file'
}
