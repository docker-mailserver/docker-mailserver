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
  _nc_wrapper 'auth/imap-auth.txt' '-w 1 0.0.0.0 143'
  assert_success
}

@test '(SASLauthd) SASL RIMAP authentication works' {
  _run_in_container testsaslauthd -u 'user1@localhost.localdomain' -p 'mypassword'
  assert_success
}

@test '(SASLauthd) RIMAP SMTP authentication works' {
  _send_email --expect-rejection \
    --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --quit-after AUTH
  assert_failure
  assert_output --partial 'Host did not advertise authentication'

  _send_email \
    --port 465 \
    --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --quit-after AUTH
  assert_output --partial 'Authentication successful'

  _send_email \
    --port 587 \
    --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --quit-after AUTH
  assert_output --partial 'Authentication successful'
}

@test '(Dovecot) master account can login' {
  _run_in_container testsaslauthd -u 'user1@localhost.localdomain*masterusername' -p 'masterpassword'
  assert_success
}
