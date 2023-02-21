load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Scripts] (helper functions inside container) '
CONTAINER_NAME='dms-test_helper_functions'

function setup_file() {
  _init_with_defaults
  _common_container_setup
}

function teardown_file() { _default_teardown ; }

@test "_sanitize_ipv4_to_subnet_cidr" {
  _run_in_container_bash "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 255.255.255.255/0"
  assert_output "0.0.0.0/0"

  _run_in_container_bash "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 192.168.255.14/20"
  assert_output "192.168.240.0/20"

  _run_in_container_bash "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 192.168.255.14/32"
  assert_output "192.168.255.14/32"
}
