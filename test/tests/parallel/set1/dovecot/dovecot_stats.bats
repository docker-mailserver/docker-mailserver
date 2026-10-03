load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Dovecot Stats] '
CONTAINER_NAME='dms-test_dovecot-stats'

function setup_file() {
  _init_with_defaults
  _common_container_setup
  _wait_for_service dovecot
}

function teardown_file() { _default_teardown ; }

@test 'stats writer socket path uses the upstream default' {
  _run_in_container doveconf -h stats_writer_socket_path
  assert_success
  assert_output 'stats-writer'
}

@test 'stats can be queried' {
  _run_in_container doveadm stats dump
  assert_success
}
