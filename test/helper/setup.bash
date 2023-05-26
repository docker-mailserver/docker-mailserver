#!/bin/bash

# ? ABOUT: Functions defined here should be used when initializing tests.

# ! ATTENTION: Functions prefixed with `__` are intended for internal use within this file only, not in tests.
# ! ATTENTION: This script must not use functions from `common.bash` to
# !            avoid dependency hell.

# ! -------------------------------------------------------------------
# ? >> Miscellaneous initialization functionality

# Does pre-flight checks for each test: check whether certain required variables
# are set and exports other variables.
#
# ## Note
#
# This function is internal and should not be used in tests.
function __initialize_variables() {
  function __check_if_set() {
    if [[ ${!1+set} != 'set' ]]; then
      echo "ERROR: (helper/setup.sh) '${1:?No variable name given to __check_if_set}' is not set" >&2
      exit 1
    fi
  }

  local REQUIRED_VARIABLES_FOR_TESTS=(
    'REPOSITORY_ROOT'
    'IMAGE_NAME'
    'CONTAINER_NAME'
  )

  for VARIABLE in "${REQUIRED_VARIABLES_FOR_TESTS[@]}"; do
    __check_if_set "${VARIABLE}"
  done

  export SETUP_FILE_MARKER TEST_TIMEOUT_IN_SECONDS NUMBER_OF_LOG_LINES
  SETUP_FILE_MARKER="${BATS_TMPDIR:?}/$(basename "${BATS_TEST_FILENAME:?}").setup_file"
  TEST_TIMEOUT_IN_SECONDS=${TEST_TIMEOUT_IN_SECONDS:-120}
  NUMBER_OF_LOG_LINES=${NUMBER_OF_LOG_LINES:-10}
}

# ? << Miscellaneous initialization functionality
# ! -------------------------------------------------------------------
# ? >> File setup

# Print the private config path for the given container or test file,
# if no container name was given.
#
# @param ${1} = container name [OPTIONAL]
function _print_private_config_path() {
  local TARGET_NAME=${1:-$(basename "${BATS_TEST_FILENAME}")}
  echo "${REPOSITORY_ROOT}/test/duplicate_configs/${TARGET_NAME}"
}


# Create a dedicated configuration directory for a test file.
#
# @param ${1} = relative source in test/config folder
# @param ${2} = (optional) container name, defaults to ${BATS_TEST_FILENAME}
# @return     = path to the folder where the config is duplicated
function _duplicate_config_for_container() {
  local OUTPUT_FOLDER
  OUTPUT_FOLDER=$(_print_private_config_path "${2}")

  if [[ -z ${OUTPUT_FOLDER} ]]; then
    echo "'OUTPUT_FOLDER' in '_duplicate_config_for_container' is empty" >&2
    return 1
  fi

  rm -rf "${OUTPUT_FOLDER:?}/"
  mkdir -p "${OUTPUT_FOLDER}"
  cp -r "${REPOSITORY_ROOT}/test/config/${1:?}/." "${OUTPUT_FOLDER}" || return $?

  echo "${OUTPUT_FOLDER}"
}

# Common defaults appropriate for most tests.
#
# Override variables in test cases within a file when necessary:
# - Use `export <VARIABLE>` in `setup_file()` to overrides for all test cases.
# - Use `local <VARIABLE>` to override within a specific test case.
#
# ## Attenton
#
# The ENV `CONTAINER_NAME` must be set before this method is called. It only affects the
# `TEST_TMP_CONFIG` directory created, but will be used in `common_container_create()`
# and implicitly in other helper methods.
#
# ## Example
#
# For example, if you need an immutable config volume that can't be affected by other tests
# in the file, then use `local TEST_TMP_CONFIG=$(_duplicate_config_for_container . "${UNIQUE_ID_HERE}")`
function _init_with_defaults() {
  __initialize_variables

  export TEST_TMP_CONFIG
  TEST_TMP_CONFIG=$(_duplicate_config_for_container . "${CONTAINER_NAME}")

  # Common complimentary test files, read-only safe to share across containers:
  export TEST_FILES_CONTAINER_PATH='/tmp/docker-mailserver-test'
  export TEST_FILES_VOLUME="${REPOSITORY_ROOT}/test/test-files:${TEST_FILES_CONTAINER_PATH}:ro"

  # The config volume cannot be read-only as some data needs to be written at container startup
  #
  # - two sed failures (unknown lines)
  # - dovecot-quotas.cf (setup-stack.sh:_setup_dovecot_quotas)
  # - postfix-aliases.cf (setup-stack.sh:_setup_postfix_aliases)
  # TODO: Check how many tests need write access. Consider using `docker create` + `docker cp` for easier cleanup.
  export TEST_CONFIG_VOLUME="${TEST_TMP_CONFIG}:/tmp/docker-mailserver"

  # Default Root CA cert used in TLS tests with `openssl` commands:
  export TEST_CA_CERT="${TEST_FILES_CONTAINER_PATH}/ssl/example.test/with_ca/ecdsa/ca-cert.ecdsa.pem"
}


# ? << File setup
# ! -------------------------------------------------------------------
# ? >> Container startup

# Waits until the container has finished starting up.
#
# @param ${1} = container name
#
# TODO: Should also fail early on "docker logs ${1} | egrep '^[  FATAL  ]'"?
function _wait_for_finished_setup_in_container() {
  local TARGET_CONTAINER_NAME=${1:?Container name must be provided}
  local STATUS=0
  _repeat_until_success_or_timeout \
    --fatal-test "_container_is_running ${1}" \
    "${TEST_TIMEOUT_IN_SECONDS}" \
    bash -c "docker logs ${TARGET_CONTAINER_NAME} | grep 'is up and running'" || STATUS=1

  if [[ ${STATUS} -eq 1 ]]; then
    echo "Last ${NUMBER_OF_LOG_LINES} lines of container (${TARGET_CONTAINER_NAME}) log"
    docker logs "${1}" | tail -n "${NUMBER_OF_LOG_LINES}"
  fi

  return "${STATUS}"
}

# Uses `docker create` to create a container with proper defaults without starting it instantly.
#
# @param ${1} = Pass an array by it's variable name as a string; it will be used as a
#               reference for appending extra config into the `docker create` below [OPTIONAL]
#
# ## Note
#
# Using array reference for a single input parameter, as this method is still
# under development while adapting tests to it and requirements it must serve
# (eg: support base config matrix in CI)
function _common_container_create() {
  [[ -n ${1} ]] && local -n X_EXTRA_ARGS=${1}

  run docker create \
    --tty \
    --name "${CONTAINER_NAME}" \
    --hostname "${TEST_FQDN:-mail.example.test}" \
    --volume "${TEST_FILES_VOLUME}" \
    --volume "${TEST_CONFIG_VOLUME}" \
    --env ENABLE_AMAVIS=0 \
    --env ENABLE_CLAMAV=0 \
    --env ENABLE_UPDATE_CHECK=0 \
    --env ENABLE_SPAMASSASSIN=0 \
    --env ENABLE_FAIL2BAN=0 \
    --env POSTFIX_INET_PROTOCOLS=ipv4 \
    --env DOVECOT_INET_PROTOCOLS=ipv4 \
    --env LOG_LEVEL=debug \
    "${X_EXTRA_ARGS[@]}" \
    "${IMAGE_NAME}"

  assert_success
}

# Starts a container given by it's name.
# Uses `CONTAINER_NAME` as the name for the `docker start` command.
#
# ## Attenton
#
# The ENV `CONTAINER_NAME` must be set before this method is called.
function _common_container_start() {
  run docker start "${CONTAINER_NAME:?Container name must be set}"
  assert_success
}

# Using `create` and `start` instead of only `run` allows to modify
# the container prior to starting it. Otherwise use this combined method.
#
# ## Note
#
# This function forwards all arguments to `_common_container_create` at present.
function _common_container_setup() {
  _common_container_create "${@}"
  _common_container_start

  _wait_for_finished_setup_in_container "${CONTAINER_NAME}"
}

# Can be used in BATS' `teardown_file` function as a default value.
#
# @param ${1} = container name [OPTIONAL]
function _default_teardown() {
  local TARGET_CONTAINER_NAME=${1:-${CONTAINER_NAME}}
  docker rm -f "${TARGET_CONTAINER_NAME}"
}
