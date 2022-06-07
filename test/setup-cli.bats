load 'test_helper/common'

# Globals referenced from `test_helper/common`:
# TEST_NAME (should match the filename, minus the bats extension)

# This is a bare minimal container setup.
# All test-cases run sequentially against the same container instance,
# no state is reset between test-cases.
function setup_file() {
  # Initializes common default vars to prepare a DMS container with:
  init_with_defaults
  # Creates and starts the container:
  common_container_setup
}

function teardown_file() {
  docker rm -f "${TEST_NAME}"
}
