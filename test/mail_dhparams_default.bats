load 'test_helper/common'

# Test case
# ---------
# By default, this image is using audited FFDHE groups (https://github.com/tomav/docker-mailserver/pull/1463)
#
# This test case covers the described case against both boolean states for `ONE_DIR`.
#
# Description:
# - When no DHE parameters are supplied by the user:
#   ~ The file `ffdhe4096.pem` has not been modified (checksum verification).
#   ~ `ffdhe4096.pem` is copied to the configuration directories for postfix and dovecot.


function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    local PRIVATE_CONFIG
    PRIVATE_CONFIG="$(duplicate_config_for_container . mail_default_dhparams_both_one_dir)"
    docker run -d --name mail_default_dhparams_one_dir \
		-v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-e DMS_DEBUG=0 \
		-e ONE_DIR=1 \
		-h mail.my-domain.com -t "${NAME}"
    wait_for_finished_setup_in_container mail_default_dhparams_one_dir

    PRIVATE_CONFIG="$(duplicate_config_for_container . mail_default_dhparams_both_not_one_dir)"
    docker run -d --name mail_default_dhparams_not_one_dir \
		-v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-e DMS_DEBUG=0 \
		-e ONE_DIR=0 \
		-h mail.my-domain.com -t "${NAME}"
    wait_for_finished_setup_in_container mail_default_dhparams_not_one_dir
}

function teardown_file() {
    docker rm -f mail_default_dhparams_one_dir
    docker rm -f mail_default_dhparams_not_one_dir
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking ssl: checking dhe params are sufficient" {
  # reference used: (22/04/2020) https://english.ncsc.nl/publications/publications/2019/juni/01/it-security-guidelines-for-transport-layer-security-tls

  # check ffdhe params are inchanged
  REPO_CHECKSUM=$(sha512sum "$(pwd)/target/shared/ffdhe4096.pem" | awk '{print $1}')
  MOZILLA_CHECKSUM=$(curl https://ssl-config.mozilla.org/ffdhe4096.txt -s | sha512sum | awk '{print $1}')
  assert_equal "${REPO_CHECKSUM}" "${MOZILLA_CHECKSUM}"
  run echo "${REPO_CHECKSUM}"
  refute_output '' # checksum must not be empty

  # by default, ffdhe4096 should be used

  # ONE_DIR=1
  DOCKER_DOVECOT_CHECKSUM_ONE_DIR=$(docker exec mail_default_dhparams_one_dir sha512sum /etc/dovecot/dh.pem | awk '{print $1}')
  DOCKER_POSTFIX_CHECKSUM_ONE_DIR=$(docker exec mail_default_dhparams_one_dir sha512sum /etc/postfix/dhparams.pem | awk '{print $1}')
  assert_equal "${DOCKER_DOVECOT_CHECKSUM_ONE_DIR}" "${REPO_CHECKSUM}"
  assert_equal "${DOCKER_POSTFIX_CHECKSUM_ONE_DIR}" "${REPO_CHECKSUM}"

  # ONE_DIR=0
  DOCKER_DOVECOT_CHECKSUM_NOT_ONE_DIR=$(docker exec mail_default_dhparams_not_one_dir sha512sum /etc/dovecot/dh.pem | awk '{print $1}')
  DOCKER_POSTFIX_CHECKSUM_NOT_ONE_DIR=$(docker exec mail_default_dhparams_not_one_dir sha512sum /etc/postfix/dhparams.pem | awk '{print $1}')
  assert_equal "${DOCKER_DOVECOT_CHECKSUM_NOT_ONE_DIR}" "${REPO_CHECKSUM}"
  assert_equal "${DOCKER_POSTFIX_CHECKSUM_NOT_ONE_DIR}" "${REPO_CHECKSUM}"
}


@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
