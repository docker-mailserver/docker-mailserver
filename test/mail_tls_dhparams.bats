load 'test_helper/common'

# Test case
# ---------
# By default, this image is using audited FFDHE groups (https://github.com/docker-mailserver/docker-mailserver/pull/1463)
#
# This test case covers the described case against both boolean states for `ONE_DIR`.
#
# Description:
# 1. Verify that the file `ffdhe4096.pem` has not been modified (checksum verification).
# 2. Verify Postfix and Dovecot are using the default `ffdhe4096.pem` from Dockerfile build.
# 3. When custom DHE parameters are supplied by the user as `/tmp/docker-mailserver/dhparams.pem`:
#    - Verify Postfix and Dovecot use the custom `custom-dhe-params.pem` (contents is actually `ffdhe2048.pem`).
#    - A warning is raised about usage of potentially insecure parameters.

function teardown() {
  docker rm -f mail_dhparams
}

function setup_file() {
  # Delegated container setup to common_container_setup
  # DRY - Explicit config changes between tests are more apparent this way.

  # Global scope
  # Copies all of `./test/config/` to specific directory for testing
  # `${PRIVATE_CONFIG}` becomes `$(pwd)/test/duplicate_configs/<bats test filename>`
  export PRIVATE_CONFIG

  export DMS_ONE_DIR=1 # default

  local DH_DEFAULT_PARAMS
  export DH_DEFAULT_CHECKSUM
  export DH_CUSTOM_PARAMS
  export DH_CUSTOM_CHECKSUM

  DH_DEFAULT_PARAMS="$(pwd)/target/shared/ffdhe4096.pem"
  DH_DEFAULT_CHECKSUM=$(sha512sum "${DH_DEFAULT_PARAMS}" | awk '{print $1}')

  DH_CUSTOM_PARAMS="$(pwd)/test/test-files/ssl/custom-dhe-params.pem"
  DH_CUSTOM_CHECKSUM=$(sha512sum "${DH_CUSTOM_PARAMS}" | awk '{print $1}')
}

# Not used
# function teardown_file() {
# }

@test "testing tls: DH Parameters - Verify integrity of Default (ffdhe4096)" {
  # Reference used (22/04/2020):
  # https://english.ncsc.nl/publications/publications/2019/juni/01/it-security-guidelines-for-transport-layer-security-tls

  run echo "${DH_DEFAULT_CHECKSUM}"
  refute_output '' # checksum must not be empty

  # Verify the FFDHE params file has not been modified (equivalent to `target/shared/ffdhe4096.pem.sha512sum`):
  local DH_MOZILLA_CHECKSUM
  DH_MOZILLA_CHECKSUM=$(curl https://ssl-config.mozilla.org/ffdhe4096.txt -s | sha512sum | awk '{print $1}')
  assert_equal "${DH_DEFAULT_CHECKSUM}" "${DH_MOZILLA_CHECKSUM}"
}

@test "testing tls: DH Parameters - Default [ONE_DIR=0]" {
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_dhparams_default_0)
  DMS_ONE_DIR=0

  common_container_setup
  should_have_valid_checksum "${DH_DEFAULT_CHECKSUM}"
}

@test "testing tls: DH Parameters - Default [ONE_DIR=1]" {
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_dhparams_default_1)

  common_container_setup
  should_have_valid_checksum "${DH_DEFAULT_CHECKSUM}"
}

@test "testing tls: DH Parameters - Custom [ONE_DIR=0]" {
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_dhparams_custom_0)
  # shellcheck disable=SC2030
  DMS_ONE_DIR=0

  cp "${DH_CUSTOM_PARAMS}" "${PRIVATE_CONFIG}/dhparams.pem"

  common_container_setup
  should_have_valid_checksum "${DH_CUSTOM_CHECKSUM}"
  should_emit_warning
}

@test "testing tls: DH Parameters - Custom [ONE_DIR=1]" {
  # shellcheck disable=SC2030
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_dhparams_custom_1)

  cp "${DH_CUSTOM_PARAMS}" "${PRIVATE_CONFIG}/dhparams.pem"

  common_container_setup
  should_have_valid_checksum "${DH_CUSTOM_CHECKSUM}"
  should_emit_warning
}

function common_container_setup() {
  # shellcheck disable=SC2031
  docker run -d --name mail_dhparams \
    -v "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
    -v "$(pwd)/test/test-files:/tmp/docker-mailserver-test:ro" \
    -e ONE_DIR="${DMS_ONE_DIR}" \
    -h mail.my-domain.com \
    --tty \
    "${NAME}"

  wait_for_finished_setup_in_container mail_dhparams
}

# Ensures the docker image services (Postfix and Dovecot) have the intended DH files
function should_have_valid_checksum() {
  local DH_CHECKSUM=$1

  local DH_CHECKSUM_DOVECOT
  DH_CHECKSUM_DOVECOT=$(docker exec mail_dhparams sha512sum /etc/dovecot/dh.pem | awk '{print $1}')
  assert_equal "${DH_CHECKSUM_DOVECOT}" "${DH_CHECKSUM}"

  local DH_CHECKSUM_POSTFIX
  DH_CHECKSUM_POSTFIX=$(docker exec mail_dhparams sha512sum /etc/postfix/dhparams.pem | awk '{print $1}')
  assert_equal "${DH_CHECKSUM_POSTFIX}" "${DH_CHECKSUM}"
}

function should_emit_warning() {
  run sh -c "docker logs mail_dhparams | grep 'Using self-generated dhparams is considered insecure.'"
  assert_success
}
