load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Daemon start] '

# Regression tests for https://github.com/docker-mailserver/docker-mailserver/issues/4708
#
# With `startsecs=0` supervisor marks a service as `RUNNING` right away, so a service that crashes at once is restarted
# forever. With `startsecs=1` it has to stay up for a second, or `supervisorctl start` fails and so does the DMS startup.

function teardown() { _default_teardown ; }

# Waits until the container logged the message `${1}` and then stopped itself.
function _wait_for_failed_startup() {
  _repeat_until_success_or_timeout 60 bash -c "docker logs ${CONTAINER_NAME} 2>&1 | grep -F '${1}'"
  _repeat_until_success_or_timeout 60 bash -c "[[ \$(docker inspect -f '{{.State.Running}}' ${CONTAINER_NAME}) == 'false' ]]"
}

@test "should start a daemon after the daemons it depends on" {
  export CONTAINER_NAME='dms-test_daemon-start_order'

  # Daemons between two barriers (see `start-mailserver.sh`) start concurrently, the barriers keep the order of the rest:
  # Valkey, then Rspamd, then Postfix, then the daemons that depend on Postfix.
  local CUSTOM_SETUP_ARGUMENTS=(--env ENABLE_RSPAMD=1)
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_service changedetector

  # PIDs are assigned in ascending order, `sort --check` fails when a daemon was started before one of its predecessors:
  # shellcheck disable=SC2016
  _run_in_container_bash 'for SERVICE in rspamd-valkey rspamd postfix changedetector; do supervisorctl pid "${SERVICE}"; done | sort --numeric-sort --check'
  assert_success
}

@test "should fail the startup when a daemon exits right after it was started" {
  export CONTAINER_NAME='dms-test_daemon-start_crash'

  local CUSTOM_SETUP_ARGUMENTS=(--env ENABLE_OPENDKIM=1)
  _init_with_defaults
  # OpenDKIM exits immediately on an invalid configuration:
  printf '#!/bin/bash\necho "invalid {{{" >/etc/opendkim.conf\n' >"${TEST_TMP_CONFIG}/user-patches.sh"
  _common_container_create 'CUSTOM_SETUP_ARGUMENTS'
  _common_container_start

  _wait_for_failed_startup 'opendkim: ERROR (spawn error)'
}

@test "should fail the startup when Postfix exits right after it was started" {
  export CONTAINER_NAME='dms-test_daemon-start_postfix'

  _init_with_defaults
  # Postfix exits with a fatal error on a line in `main.cf` that is not a `key = value` pair
  # (the `pidproxy` wrapper of Postfix only notices that after its polling interval, which has to stay below `startsecs`):
  printf '#!/bin/bash\necho "invalid" >>/etc/postfix/main.cf\n' >"${TEST_TMP_CONFIG}/user-patches.sh"
  _common_container_create
  _common_container_start

  _wait_for_failed_startup 'postfix: ERROR (spawn error)'
}

@test "should fail the startup when getmail is enabled without a configuration" {
  export CONTAINER_NAME='dms-test_daemon-start_getmail'

  local CUSTOM_SETUP_ARGUMENTS=(--env ENABLE_GETMAIL=1)
  _init_with_defaults
  rm -r "${TEST_TMP_CONFIG}/getmail"
  _common_container_create 'CUSTOM_SETUP_ARGUMENTS'
  _common_container_start

  _wait_for_failed_startup 'there is no valid Getmail configuration'
}

@test "should fail the startup when getmail is enabled in parallel mode without a valid configuration" {
  export CONTAINER_NAME='dms-test_daemon-start_getmail-parallel'

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_GETMAIL=1
    --env GETMAIL_PARALLEL=1
  )
  _init_with_defaults
  # Parallel mode creates one service per configuration, and skips names with characters other than `A-Z a-z 0-9 . _ -`
  # (the name `user%7` is skipped), so no service exists at all:
  find "${TEST_TMP_CONFIG}/getmail" -type f ! -name 'user%7.cf' -delete
  _common_container_create 'CUSTOM_SETUP_ARGUMENTS'
  _common_container_start

  _wait_for_failed_startup 'there is no valid Getmail configuration'
}
