load 'test_helper/common'

# Test case
# ---------
# By default, this image is using audited FFDHE groups (https://github.com/tomav/docker-mailserver/pull/1463)
#
# This test case covers the described case when `ONE_DIR=0`.
#
# Description:
# - When custom DHE parameters are supplied by the user:
#   ~ User supplied DHE parameters are copied to the configuration directories for postfix and dovecot.
#   ~ A warning is raised about usage of insecure parameters.


function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)
  # copy the custom DHE params in local config
  cp "$(pwd)/test/test-files/ssl/custom-dhe-params.pem" "${PRIVATE_CONFIG}/dhparams.pem"

  docker run -d --name mail_manual_dhparams_not_one_dir \
		-v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-e DMS_DEBUG=0 \
		-e ONE_DIR=0 \
		-h mail.my-domain.com -t "${NAME}"
    wait_for_finished_setup_in_container mail_manual_dhparams_not_one_dir
}

function teardown_file() {
  docker rm -f mail_manual_dhparams_not_one_dir
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking dhparams: ONE_DIR=0 check manual dhparams is used" {
  test_checksum=$(sha512sum "$(pwd)/test/test-files/ssl/custom-dhe-params.pem" | awk '{print $1}')
  run echo "${test_checksum}"
  refute_output '' # checksum must not be empty

  docker_dovecot_checksum=$(docker exec mail_manual_dhparams_not_one_dir sha512sum /etc/dovecot/dh.pem | awk '{print $1}')
  docker_postfix_checksum=$(docker exec mail_manual_dhparams_not_one_dir sha512sum /etc/postfix/dhparams.pem | awk '{print $1}')
  assert_equal "${docker_dovecot_checksum}" "${test_checksum}"
  assert_equal "${docker_postfix_checksum}" "${test_checksum}"
}

@test "checking dhparams: ONE_DIR=0 check warning output when using manual dhparams" {
  run sh -c "docker logs mail_manual_dhparams_not_one_dir | grep 'Using self-generated dhparams is considered as insecure'"
  assert_success
}

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
