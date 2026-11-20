load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[PostSRSd] '
CONTAINER_NAME='dms-test_postsrsd-nofile-limit'

# Regression test for https://github.com/docker-mailserver/docker-mailserver/issues/4864
#
# PostSRSd closes every FD up to the soft `nofile` limit before it binds its ports. Recent Docker releases default to
# a limit of ~1 billion, which would keep PostSRSd from ever listening. The limit that is available on a host depends
# on `fs.nr_open`, so instead of reproducing the hang, this verifies the limit PostSRSd actually runs with.

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_SRS=1
    # Well above what PostSRSd needs, but below `fs.nr_open` (1048576 by default), so it can be set on any host:
    --ulimit 'nofile=524288:524288'
  )
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _wait_for_service postsrsd
  _wait_for_tcp_port_in_container 10001
  _wait_for_tcp_port_in_container 10002
}

function teardown_file() { _default_teardown ; }

@test "should lower the soft nofile limit of PostSRSd" {
  # Column 4 of `Max open files` is the soft limit (`Max open files  <soft>  <hard>  files`):
  _run_in_container_bash "awk '/^Max open files/ { print \$4 }' /proc/\$(pgrep --oldest -x postsrsd)/limits"
  assert_success
  assert_output '65536'
}

@test "should keep the hard nofile limit of the container" {
  _run_in_container_bash "awk '/^Max open files/ { print \$5 }' /proc/\$(pgrep --oldest -x postsrsd)/limits"
  assert_success
  assert_output '524288'
}
