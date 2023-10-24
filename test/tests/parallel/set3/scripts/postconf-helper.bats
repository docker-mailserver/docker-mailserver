load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Scripts] (helper functions) (postfix - _add_to_or_update_postfix_main) '
CONTAINER_NAME='dms-test_postconf-helper'
# Various tests for the helper function `_add_to_or_update_postfix_main()`
function setup_file() {
  _init_with_defaults
  _common_container_setup
  # Begin tests without 'relayhost' defined in 'main.cf'
  _run_in_container postconf -X relayhost
  assert_success
}
function teardown_file() { _default_teardown ; }
# Add or modify in Postfix config `main.cf` a parameter key with the provided value.
# When the key already exists, the new value is appended (default), or prepended (explicitly requested).
# NOTE: This test-case helper is hard-coded for testing with the 'relayhost' parameter.
#
# @param ${1} = new value (appended or prepended)
# @param ${2} = action "append" (default) or "prepend" [OPTIONAL]
function _modify_postfix_main_config() {
  _run_in_container_bash "source /usr/local/bin/helpers/{postfix,utils}.sh && _add_to_or_update_postfix_main relayhost '${1}' '${2}'"
  _run_in_container grep '^relayhost' '/etc/postfix/main.cf'
}
@test "check if initial value is empty" {
  _run_in_container postconf -h 'relayhost'
  assert_output ''
}
@test "add single value" {
  _modify_postfix_main_config 'single-value-test'
  assert_output 'relayhost = single-value-test'
}
@test "prepend value" {
  _modify_postfix_main_config 'prepend-test' 'prepend'
  assert_output 'relayhost = prepend-test single-value-test'
}
@test "append value (explicit)" {
  _modify_postfix_main_config 'append-test-explicit' 'append'
  assert_output 'relayhost = prepend-test single-value-test append-test-explicit'
}
@test "append value (implicit)" {
  _modify_postfix_main_config 'append-test-implicit'
  assert_output 'relayhost = prepend-test single-value-test append-test-explicit append-test-implicit'
}
@test "try to append already existing value" {
  _modify_postfix_main_config 'append-test-implicit'
  assert_output 'relayhost = prepend-test single-value-test append-test-explicit append-test-implicit'
}
