load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Getmail] '
CONTAINER_NAME='dms-test_getmail'

function setup_file() {
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(--env 'ENABLE_GETMAIL=1')
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test 'default configuration exists and is correct' {
  _run_in_container cat /etc/getmailrc_general
  assert_success
  assert_output '[options]
verbose = 0
read_all = false
delete = false
max_messages_per_session = 500
received = false
delivered_to = false
'

  _run_in_container stat /usr/local/bin/debug-getmail
  assert_success
  _run_in_container stat /usr/local/bin/getmail-cron
  assert_success
}

@test 'debug-getmail works as expected' {
  _run_in_container /usr/local/bin/debug-getmail
  assert_success
}
