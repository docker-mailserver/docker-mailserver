load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_NAME_PREFIX='helper functions inside container:'
CONTAINER_NAME='dms-test-helper_functions'

function setup_file() {
  init_with_defaults
  common_container_setup
}

function teardown_file() { _default_teardown ; }

@test "${TEST_NAME_PREFIX} _sanitize_ipv4_to_subnet_cidr" {
  _run_in_container bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 255.255.255.255/0"
  assert_output "0.0.0.0/0"

  _run_in_container bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 192.168.255.14/20"
  assert_output "192.168.240.0/20"

  _run_in_container bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 192.168.255.14/32"
  assert_output "192.168.255.14/32"
}
