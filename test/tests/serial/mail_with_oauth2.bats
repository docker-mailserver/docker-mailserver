load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[OAuth2] '
CONTAINER1_NAME='dms-test_oauth2'
CONTAINER2_NAME='dms-test_oauth2_provider'

function setup_file() {
  export DMS_TEST_NETWORK='test-network-oauth2'
  export DMS_DOMAIN='example.test'
  export FQDN_MAIL="mail.${DMS_DOMAIN}"
  export FQDN_OAUTH2="auth.${DMS_DOMAIN}"

  # Link the test containers to separate network:
  # NOTE: If the network already exists, test will fail to start.
  docker network create "${DMS_TEST_NETWORK}"

  # Setup local oauth2 provider service:
  docker run --rm -d --name "${CONTAINER2_NAME}" \
    --hostname "${FQDN_OAUTH2}" \
    --network "${DMS_TEST_NETWORK}" \
    --volume "${REPOSITORY_ROOT}/test/config/oauth2/Caddyfile:/etc/caddy/Caddyfile:ro" \
    caddy:2.7

  _run_until_success_or_timeout 20 bash -c "docker logs ${CONTAINER2_NAME} 2>&1 | grep 'serving initial configuration'"

  #
  # Setup DMS container
  #

  # Add OAuth2 configuration so that Dovecot can query our mocked identity provider (CONTAINER2)
  local ENV_OAUTH2_CONFIG=(
    --env ENABLE_OAUTH2=1
    --env OAUTH2_INTROSPECTION_URL=http://auth.example.test/userinfo
  )

  export CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    "${ENV_OAUTH2_CONFIG[@]}"

    --hostname "${FQDN_MAIL}"
    --network "${DMS_TEST_NETWORK}"
  )

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_tcp_port_in_container 143

  # Set default implicit container fallback for helpers:
  export CONTAINER_NAME=${CONTAINER1_NAME}

  # An initial connection needs to be made first, otherwise the auth attempts fail
  _run_in_container_bash 'nc -vz 0.0.0.0 143'
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
  docker network rm "${DMS_TEST_NETWORK}"
}

@test "should authenticate with XOAUTH2" {
  # curl 7.80.0 (Nov 2021) broke XOAUTH2 support (DMS v14 release with Debian 12 packages curl 7.88.1)
  # https://github.com/docker-mailserver/docker-mailserver/pull/3403#issuecomment-1907100624
  #
  # Fixed in curl 8.6.0 (Jan 31 2024):
  # - https://github.com/curl/curl/issues/10259
  # - https://github.com/curl/curl/commit/7b2d98dfadf209108aa7772ee21ae42e3dab219f (referenced in release changelog by commit title)
  # - https://github.com/curl/curl/releases/tag/curl-8_6_0
  skip 'unable to test XOAUTH2 mechanism due to bug in curl versions 7.80.0 --> 8.5.0'

  __should_login_successfully_with 'XOAUTH2'
}

@test "should authenticate with OAUTHBEARER" {
  __should_login_successfully_with 'OAUTHBEARER'
}

function __should_login_successfully_with() {
  local AUTH_METHOD=${1}
  # These values are the auth credentials checked against the Caddy `/userinfo` endpoint:
  local USER_ACCOUNT='user1@localhost.localdomain'
  local ACCESS_TOKEN='DMS_YWNjZXNzX3Rva2Vu'

  __verify_auth_with_imap
  __verify_auth_with_smtp
}

# Dovecot direct auth verification via IMAP:
function __verify_auth_with_imap() {
  # NOTE: Include the `--verbose` option if you're troubleshooting and want to see the protocol exchange messages
  # NOTE: `--user username:password` is valid for testing `PLAIN` auth mechanism, but you should prefer swaks instead.
  _run_in_container curl --silent \
    --login-options "AUTH=${AUTH_METHOD}" --oauth2-bearer "${ACCESS_TOKEN}" --user "${USER_ACCOUNT}" \
    --url 'imap://localhost:143' -X 'LOGOUT'

  __dovecot_logs_should_verify_success
}

# Postfix delegates by default to Dovecot via SASL:
# NOTE: This won't be compatible with LDAP if `ENABLE_SASLAUTHD=1` with `ldap` SASL mechanism:
function __verify_auth_with_smtp() {
  # NOTE: `--upload-file` with some mail content seems required for using curl to test OAuth2 authentication.
  # TODO: Replace with swaks and early exit option when it supports XOAUTH2 + OAUTHBEARER:
  _run_in_container curl --silent \
    --login-options "AUTH=${AUTH_METHOD}" --oauth2-bearer "${ACCESS_TOKEN}" --user "${USER_ACCOUNT}" \
    --url 'smtp://localhost:587' --mail-from "${USER_ACCOUNT}" --mail-rcpt "${USER_ACCOUNT}" --upload-file - <<< 'RFC 5322 content - not important'

  # Postfix specific auth logs:
  _run_in_container grep 'postfix/submission/smtpd' /var/log/mail.log
  assert_output --partial "sasl_method=${AUTH_METHOD}, sasl_username=${USER_ACCOUNT}"

  # Dovecot logs should still be checked as it is handling the actual auth process under the hood:
  __dovecot_logs_should_verify_success
}

function __dovecot_logs_should_verify_success() {
  # Inspect the relevant Dovecot logs to catch failure / success:
  _service_log_should_contain_string 'mail' 'dovecot:'
  refute_output --partial 'oauth2 failed: Introspection failed'
  assert_output --partial "dovecot: imap-login: Login: user=<${USER_ACCOUNT}>, method=${AUTH_METHOD}"

  # If another PassDB is enabled, it should not have been attempted with the XOAUTH2 / OAUTHBEARER mechanisms:
  # dovecot: auth: passwd-file(${USER_ACCOUNT},127.0.0.1): Password mismatch (SHA1 of given password: d390c1) - trying the next passdb
  refute_output --partial 'trying the next passdb'
}
