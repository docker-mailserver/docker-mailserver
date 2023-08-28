load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Scripts] (helper functions) (postfix.sh) (_add_to_or_update_postfix_main) '
CONTAINER_NAME='dms-test_postconf-helper'

# Various tests for the helper function _add_to_or_update_postfix_main()

function setup_file() {
  _init_with_defaults
  _common_container_setup

  # remove 'relayhost' from main.cf
  _run_in_container postconf -X relayhost
  assert_success
}

function teardown_file() { _default_teardown ; }

# Add key 'relayhost' with a value to Postfix's main configuration file
# or update an existing key. An already existing key can be updated
# by either appending to the existing value (default) or by prepending.
#
# @param ${1} = new value (appended or prepended)
# @param ${2} = action "append" (default) or "prepend" [OPTIONAL]
function _modify_postfix_main.cf() {
  _run_in_container_bash "source /usr/local/bin/helpers/{postfix,utils}.sh && _add_to_or_update_postfix_main relayhost '$1' '$2'"
  _run_in_container grep "^relayhost" "/etc/postfix/main.cf"
}

@test "check if initial value is empty" {
  _run_in_container postconf -h "relayhost"
  assert_output ""
}

@test "add single value" {
  _modify_postfix_main.cf "single-value-test"
  assert_output "relayhost = single-value-test"
}

@test "prepend value" {
  _modify_postfix_main.cf "prepend-test" "prepend"
  assert_output "relayhost = prepend-test single-value-test"
}

@test "append value (explicit)" {
  _modify_postfix_main.cf "append-test-explicit" "append"
  assert_output "relayhost = prepend-test single-value-test append-test-explicit"
}

@test "append value (implicit)" {
  _modify_postfix_main.cf "append-test-implicit"
  assert_output "relayhost = prepend-test single-value-test append-test-explicit append-test-implicit"
}

@test "try to append already existing value" {
  _modify_postfix_main.cf "append-test-implicit"
  assert_output "relayhost = prepend-test single-value-test append-test-explicit append-test-implicit"
}
