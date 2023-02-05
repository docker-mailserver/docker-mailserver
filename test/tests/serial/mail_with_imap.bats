load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[SASLauthd + RIMAP] '
CONTAINER_NAME='dms-test_saslauthd_and_rimap'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_SASLAUTHD=1
    --env SASLAUTHD_MECH_OPTIONS=127.0.0.1
    --env SASLAUTHD_MECHANISMS=rimap
    --env PERMIT_DOCKER=container
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container mail_with_imap
}

function teardown_file() { _default_teardown ; }

@test '(Dovecot) LDAP RIMAP connection and authentication works' {
  _run_in_container_bash "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-auth.txt"
  assert_success
}

@test '(SASLauthd) SASL RIMAP authentication works' {
  _run_in_container testsaslauthd -u 'user1@localhost.localdomain' -p 'mypassword'
  assert_success
}

@test '(SASLauthd) RIMAP SMTP authentication works' {
  _run_in_container_bash 'nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt'
  assert_success
  assert_output --partial 'Authentication successful'
}

@test '(Dovecot) master account can login' {
  _run_in_container testsaslauthd -u 'user1@localhost.localdomain*masterusername' -p 'masterpassword'
  assert_success
}
