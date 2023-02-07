load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Relay Host] '
CONTAINER_NAME='dms-test_relay'

function setup_file() {
  _init_with_defaults

  mv "${TEST_TMP_CONFIG}/relay-hosts/"* "${TEST_TMP_CONFIG}/"

  local CUSTOM_SETUP_ARGUMENTS=(
    --env RELAY_HOST=default.relay.com
    --env RELAY_PORT=2525
    --env RELAY_USER=smtp_user
    --env RELAY_PASSWORD=smtp_password
    --env PERMIT_DOCKER=host
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test 'default mapping is added from ENV variables' {
  _run_in_container grep 'domainone.tld' /etc/postfix/relayhost_map
  assert_success
  assert_output --regexp '^@domainone.tld[[:space:]]+\[default.relay.com\]:2525$'
}

@test 'default mapping is added from ENV variables for virtual user entry' {
  _run_in_container grep 'domain1.tld' /etc/postfix/relayhost_map
  assert_success
  assert_output --regexp '^@domain1.tld[[:space:]]+\[default.relay.com\]:2525$'
}

@test 'default mapping is added from ENV variables for new user entry' {
  _run_in_container grep 'domainzero.tld' /etc/postfix/relayhost_map
  assert_failure

  _add_mail_account_then_wait_until_ready 'user0@domainzero.tld' 'password123'
  _run_until_success_or_timeout 20 _exec_in_container grep 'domainzero.tld' /etc/postfix/relayhost_map
  assert_success
  assert_output --regexp '^@domainzero.tld[[:space:]]+\[default.relay.com\]:2525$'
}

@test 'default mapping is added from ENV variables for new virtual user (alias) entry' {
  _run_in_container grep 'domain2.tld' /etc/postfix/relayhost_map
  assert_failure

  run ./setup.sh -c "${CONTAINER_NAME}" alias add 'user2@domain2.tld' 'user2@domaintwo.tld'
  assert_success
  _run_until_success_or_timeout 10 _exec_in_container grep 'domain2.tld' /etc/postfix/relayhost_map
  assert_success
  assert_output --regexp '^@domain2.tld[[:space:]]+\[default.relay.com\]:2525$'
}

@test 'custom mapping is added from file' {
  _run_in_container grep 'domaintwo.tld' /etc/postfix/relayhost_map
  assert_success
  assert_output --regexp '^@domaintwo.tld[[:space:]]+\[other.relay.com\]:587$'
}

@test 'ignored domain is not added' {
  _run_in_container grep domainthree.tld /etc/postfix/relayhost_map
  assert_failure
}

@test '/etc/postfix/sasl_passwd exists' {
  _run_in_container_bash '[[ -f /etc/postfix/sasl_passwd ]]'
  assert_success
}

@test 'auth entry is added' {
  _run_in_container grep '^@domaintwo.tld\s\+smtp_user_2:smtp_password_2' /etc/postfix/sasl_passwd
  assert_success
  _should_output_number_of_lines 1
}

@test 'default auth entry is added' {
  _run_in_container grep '^\[default.relay.com\]:2525\s\+smtp_user:smtp_password' /etc/postfix/sasl_passwd
  assert_success
  _should_output_number_of_lines 1
}
