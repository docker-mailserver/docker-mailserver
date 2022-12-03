#!/bin/bash

# -------------------------------------------------------------------

function __initialize_variables() {
  function __check_if_set() {
    if [[ ${!1+set} != 'set' ]]
    then
      echo "ERROR: (helper/setup.sh) '${1:?No variable name given to __check_if_set}' is not set" >&2
      exit 1
    fi
  }

  local REQUIRED_VARIABLES_FOR_TESTS=(
    'REPOSITORY_ROOT'
    'IMAGE_NAME'
    'CONTAINER_NAME'
  )

  for VARIABLE in "${REQUIRED_VARIABLES_FOR_TESTS}"
  do
    __check_if_set "${VARIABLE}"
  done

  TEST_TIMEOUT_IN_SECONDS=${TEST_TIMEOUT_IN_SECONDS:-120}
  NUMBER_OF_LOG_LINES=${NUMBER_OF_LOG_LINES:-10}
  SETUP_FILE_MARKER="${BATS_TMPDIR:?}/$(basename "${BATS_TEST_FILENAME:?}").setup_file"
}

# -------------------------------------------------------------------

# @param ${1} relative source in test/config folder
# @param ${2} (optional) container name, defaults to ${BATS_TEST_FILENAME}
# @return path to the folder where the config is duplicated
function duplicate_config_for_container() {
  local OUTPUT_FOLDER
  OUTPUT_FOLDER=$(private_config_path "${2}")  || return $?

  rm -rf "${OUTPUT_FOLDER:?}/" || return $? # cleanup
  mkdir -p "${OUTPUT_FOLDER}" || return $?
  cp -r "${PWD}/test/config/${1:?}/." "${OUTPUT_FOLDER}" || return $?

  echo "${OUTPUT_FOLDER}"
}

# TODO: Should also fail early on "docker logs ${1} | egrep '^[  FATAL  ]'"?
# @param ${1} name of the postfix container
function wait_for_finished_setup_in_container() {
  local STATUS=0
  repeat_until_success_or_timeout --fatal-test "container_is_running ${1}" "${TEST_TIMEOUT_IN_SECONDS}" sh -c "docker logs ${1} | grep 'is up and running'" || STATUS=1

  if [[ ${STATUS} -eq 1 ]]; then
    echo "Last ${NUMBER_OF_LOG_LINES} lines of container \`${1}\`'s log"
    docker logs "${1}" | tail -n "${NUMBER_OF_LOG_LINES}"
  fi

  return ${STATUS}
}

# Common defaults appropriate for most tests, override vars in each test when necessary.
# For all tests override in `setup_file()` via an `export` var.
# For individual test override the var via `local` var instead.
#
# For example, if you need an immutable config volume that can't be affected by other tests
# in the file, then use `local TEST_TMP_CONFIG=$(duplicate_config_for_container . "${UNIQUE_ID_HERE}")`
function init_with_defaults() {
  __initialize_variables

  export TEST_TMP_CONFIG

  # In `setup_file()` the default name to use for the currently tested docker container
  # is `${CONTAINER_NAME}` global defined here. It derives the name from the test filename:
  # `basename` to ignore absolute dir path and file extension, only extract filename.
  # In `setup_file()` creates a single copy of the test config folder to use for an entire test file:
  TEST_TMP_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  # Common complimentary test files, read-only safe to share across containers:
  export TEST_FILES_CONTAINER_PATH='/tmp/docker-mailserver-test'
  export TEST_FILES_VOLUME="${REPOSITORY_ROOT}/test/test-files:${TEST_FILES_CONTAINER_PATH}:ro"

  # The config volume cannot be read-only as some data needs to be written at container startup
  # - two sed failures (unknown lines)
  # - dovecot-quotas.cf (setup-stack.sh:_setup_dovecot_quotas)
  # - postfix-aliases.cf (setup-stack.sh:_setup_postfix_aliases)
  # TODO: Check how many tests need write access. Consider using `docker create` + `docker cp` for easier cleanup.
  export TEST_CONFIG_VOLUME="${TEST_TMP_CONFIG}:/tmp/docker-mailserver"

  # Default Root CA cert used in TLS tests with `openssl` commands:
  export TEST_CA_CERT="${TEST_FILES_CONTAINER_PATH}/ssl/example.test/with_ca/ecdsa/ca-cert.ecdsa.pem"
}

# Using `create` and `start` instead of only `run` allows to modify
# the container prior to starting it. Otherwise use this combined method.
# NOTE: Forwards all args to the create method at present.
function common_container_setup() {
  common_container_create "${@}"
  common_container_start
}

# Common docker setup is centralized here.
#
# `X_EXTRA_ARGS` - Optional: Pass an array by it's variable name as a string, it will
# be used as a reference for appending extra config into the `docker create` below:
#
# NOTE: Using array reference for a single input parameter, as this method is still
# under development while adapting tests to it and requirements it must serve (eg: support base config matrix in CI)
function common_container_create() {
  [[ -n ${1} ]] && local -n X_EXTRA_ARGS=${1}

  run docker create \
    --tty \
    --name "${CONTAINER_NAME}" \
    --hostname "${TEST_FQDN:-mail.my-domain.com}" \
    --volume "${TEST_FILES_VOLUME}" \
    --volume "${TEST_CONFIG_VOLUME}" \
    --env ENABLE_AMAVIS=0 \
    --env ENABLE_CLAMAV=0 \
    --env ENABLE_UPDATE_CHECK=0 \
    --env ENABLE_SPAMASSASSIN=0 \
    --env ENABLE_FAIL2BAN=0 \
    --env LOG_LEVEL=debug \
    "${X_EXTRA_ARGS[@]}" \
    "${IMAGE_NAME}"

  assert_success
}

function common_container_start() {
  run docker start "${CONTAINER_NAME}"
  assert_success

  wait_for_finished_setup_in_container "${CONTAINER_NAME}"
}
