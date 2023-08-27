load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Scripts] (helper functions) (postfix.sh) (_add_to_or_update_postfix_main) '
CONTAINER_NAME='dms-test-main.cf-changes'

# Various tests for the helper function _add_to_or_update_postfix_main()

function setup_file() {
  _init_with_defaults
  _common_container_setup

  # remove 'relayhost' from main.cf
  _run_in_container postconf -X relayhost
  assert_success

  export CONFIG=/etc/postfix/main.cf
}

function teardown_file() { _default_teardown ; }


@test "check if initial value is empty" {
  _run_in_container postconf -h relayhost
  assert_output ""
}

@test "add single value" {
  _run_in_container_bash 'source /usr/local/bin/helpers/{postfix,utils}.sh && _add_to_or_update_postfix_main relayhost single-value-test'
  _run_in_container grep "^relayhost" "${CONFIG}"

  assert_output "relayhost = single-value-test"
}

@test "prepend value" {
  _run_in_container_bash 'source /usr/local/bin/helpers/{postfix,utils}.sh && _add_to_or_update_postfix_main relayhost prepend-test prepend'
  _run_in_container grep '^relayhost' "${CONFIG}"

  assert_output "relayhost = prepend-test single-value-test"
}

@test "append value (explicit)" {
  _run_in_container_bash 'source /usr/local/bin/helpers/{postfix,utils}.sh && _add_to_or_update_postfix_main relayhost append-test-explicit append'
  _run_in_container grep '^relayhost' "${CONFIG}"

  assert_output "relayhost = prepend-test single-value-test append-test-explicit"
}

@test "append value (implicit)" {
  _run_in_container_bash 'source /usr/local/bin/helpers/{postfix,utils}.sh && _add_to_or_update_postfix_main relayhost append-test-implicit'
  _run_in_container grep '^relayhost' "${CONFIG}"

  assert_output "relayhost = prepend-test single-value-test append-test-explicit append-test-implicit"
}

@test "try to append already existing value" {
  _run_in_container_bash 'source /usr/local/bin/helpers/{postfix,utils}.sh && _add_to_or_update_postfix_main relayhost append-test-implicit'
  _run_in_container grep '^relayhost' "${CONFIG}"

  assert_output "relayhost = prepend-test single-value-test append-test-explicit append-test-implicit"
}
