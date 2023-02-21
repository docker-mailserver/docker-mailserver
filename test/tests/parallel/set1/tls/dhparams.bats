load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

# Test case
# ---------
# By default, this image is using audited FFDHE groups (https://github.com/docker-mailserver/docker-mailserver/pull/1463)
# Reference used (22/04/2020) - Page 27 (ffdhe4096 RFC 7919, regarded as sufficient):
# https://english.ncsc.nl/publications/publications/2019/juni/01/it-security-guidelines-for-transport-layer-security-tls

BATS_TEST_NAME_PREFIX='[Security] TLS (DH Parameters) '

CONTAINER1_NAME='dms-test_tls-dh-params_default'
CONTAINER2_NAME='dms-test_tls-dh-params_custom'

function teardown() { _default_teardown ; }

# Verify Postfix and Dovecot are using the default `ffdhe4096.pem` from Dockerfile build.
# Verify that the file `ffdhe4096.pem` has not been modified (checksum verification against trusted third-party copy).
@test "Default" {
  export CONTAINER_NAME=${CONTAINER1_NAME}
  local DH_PARAMS_DEFAULT='target/shared/ffdhe4096.pem'
  local DH_CHECKSUM_DEFAULT=$(sha512sum "${DH_PARAMS_DEFAULT}" | awk '{print $1}')

  _init_with_defaults
  _common_container_setup

  _should_match_service_copies "${DH_CHECKSUM_DEFAULT}"

  # Verify integrity of the default supplied DH Params (ffdhe4096, should be equivalent to `target/shared/ffdhe4096.pem.sha512sum`):
  # 716a462baecb43520fb1ba6f15d288ba8df4d612bf9d450474b4a1c745b64be01806e5ca4fb2151395fd4412a98831b77ea8dfd389fe54a9c768d170b9565a25
  local DH_CHECKSUM_MOZILLA
  DH_CHECKSUM_MOZILLA=$(curl https://ssl-config.mozilla.org/ffdhe4096.txt -s | sha512sum | awk '{print $1}')
  assert_equal "${DH_CHECKSUM_DEFAULT}" "${DH_CHECKSUM_MOZILLA}"
}

# When custom DHE parameters are supplied by the user to `/tmp/docker-mailserver/dhparams.pem`:
# - Verify Postfix and Dovecot use the custom `custom-dhe-params.pem` (contents tested is actually `ffdhe2048.pem`).
# - A warning is raised about usage of potentially insecure parameters.
@test "Custom" {
  export CONTAINER_NAME=${CONTAINER2_NAME}
  local DH_PARAMS_CUSTOM='test/test-files/ssl/custom-dhe-params.pem'
  local DH_CHECKSUM_CUSTOM=$(sha512sum "${DH_PARAMS_CUSTOM}" | awk '{print $1}')

  _init_with_defaults
  cp "${DH_PARAMS_CUSTOM}" "${TEST_TMP_CONFIG}/dhparams.pem"
  _common_container_setup

  _should_match_service_copies "${DH_CHECKSUM_CUSTOM}"

  # Should emit a warning:
  run docker logs "${CONTAINER_NAME}"
  assert_success
  assert_output --partial '[ WARNING ]  Using self-generated dhparams is considered insecure - unless you know what you are doing, please remove'
}

# Ensures the docker image services (Postfix and Dovecot) have the expected DH files:
function _should_match_service_copies() {
  local DH_CHECKSUM=$1

  function __should_have_expected_checksum() {
    _run_in_container_bash "sha512sum ${1} | awk '{print \$1}'"
    assert_success
    assert_output "${DH_CHECKSUM}"
  }

  __should_have_expected_checksum '/etc/dovecot/dh.pem'
  __should_have_expected_checksum '/etc/postfix/dhparams.pem'
}
