load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

# Originally contributed Jan 2017:
# https://github.com/docker-mailserver/docker-mailserver/pull/461
# Refactored with additional insights:
# https://github.com/docker-mailserver/docker-mailserver/pull/3004

# NOTE: Purpose of feature is to use an ENV instead of providing a `postfix-main.cf`
# to configure a URI for sending mail to an alternative LMTP server.
# TODO: A more appropriate test if keeping this feature would be to run Dovecot via a
# separate container to deliver mail to, and verify it was stored in the expected mail dir.

BATS_TEST_NAME_PREFIX='[ENV] (POSTFIX_DAGENT) '
CONTAINER_NAME='dms-test_env_postfix-dagent'

function setup_file() {
  export LMTP_URI='lmtp:127.0.0.1:24'
  _init_with_defaults

  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env PERMIT_DOCKER='container'
    --env POSTFIX_DAGENT="${LMTP_URI}"
  )

  # Configure LMTP service listener in `/etc/dovecot/conf.d/10-master.conf` to instead listen on TCP port 24:
  mv "${TEST_TMP_CONFIG}/dovecot-lmtp/user-patches.sh" "${TEST_TMP_CONFIG}/"

  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'
}

function teardown_file() { _default_teardown ; }

@test "should have updated the value of 'main.cf:virtual_transport'" {
  _run_in_container grep "virtual_transport = ${LMTP_URI}" /etc/postfix/main.cf
  assert_success
}

@test "delivers mail to existing account" {
  _wait_for_smtp_port_in_container
  _send_email 'email-templates/existing-user1' # send a test email

  # Verify delivery was successful, log line should look similar to:
  # postfix/lmtp[1274]: 0EA424ABE7D9: to=<user1@localhost.localdomain>, relay=127.0.0.1[127.0.0.1]:24, delay=0.13, delays=0.07/0.01/0.01/0.05, dsn=2.0.0, status=sent (250 2.0.0 <user1@localhost.localdomain> ixPpB+Zvv2P7BAAAUi6ngw Saved)
  local MATCH_LOG_LINE='postfix/lmtp.* status'
  _run_in_container_bash "timeout 60 tail -F /var/log/mail/mail.log | grep --max-count 1 '${MATCH_LOG_LINE}'"
  assert_success
  # Assertion of full pattern here (instead of via grep) is a bit more helpful for debugging partial failures:
  assert_output --regexp "${MATCH_LOG_LINE}=sent .* Saved)"
}
