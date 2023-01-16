load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Process Management] '
CONTAINER1_NAME='dms-test_process-check-restart_enabled'
CONTAINER2_NAME='dms-test_process-check-restart_disabled'
CONTAINER_NAME=${CONTAINER1_NAME}

function setup_file() {
  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_CLAMAV=1
    --env ENABLE_FAIL2BAN=1
    --env ENABLE_FETCHMAIL=1
    --env ENABLE_POSTGREY=1
    --env ENABLE_SASLAUTHD=1
    --env ENABLE_SRS=1
    --env SMTP_ONLY=0
    # Required workaround for some environments when using ENABLE_SRS=1:
    # PR 2730: https://github.com/docker-mailserver/docker-mailserver/commit/672e9cf19a3bb1da309e8cea6ee728e58f905366
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  init_with_defaults
  # Average time: 6 seconds
  common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'
}

function teardown_file() { _default_teardown ; }

### Core processes (always running) ###

@test "process should restart when killed (OpenDKIM)" {
  _should_restart_when_killed 'opendkim'
}

@test "process should restart when killed (OpenDMARC)" {
  _should_restart_when_killed 'opendmarc'
}

@test "process should restart when killed (Postfix)" {
  _should_restart_when_killed 'master'
}

### ENV dependent processes ###

@test "process should restart when killed (Amavis)" {
  _should_restart_when_killed 'amavi'
}

@test "process should restart when killed (ClamAV)" {
  _should_restart_when_killed 'clamd'
}

@test "process should restart when killed (Dovecot)" {
  _should_restart_when_killed 'dovecot'
}

@test "process should restart when killed (Fail2Ban)" {
  _should_restart_when_killed 'fail2ban-server'
}

@test "process should restart when killed (Fetchmail)" {
  _should_restart_when_killed 'fetchmail'
}

@test "process should restart when killed (Postgrey)" {
  _should_restart_when_killed 'postgrey'
}

@test "process should restart when killed (PostSRSd)" {
  _should_restart_when_killed 'postsrsd'
}

@test "process should restart when killed (saslauthd)" {
  _should_restart_when_killed 'saslauthd'
}

function _should_restart_when_killed() {
  local PROCESS=${1}
  run_until_success_or_timeout 10 check_if_process_is_running "${PROCESS}"
  assert_success

  _run_in_container pkill "${PROCESS}"
  assert_success

  run_until_success_or_timeout 10 check_if_process_is_running "${PROCESS}"
}

# Previous `check` and `restart` test case commands before the new version (now migrated into `_should_restart_when_killed()`):
# run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/opendkim'"
# run docker exec mail /bin/bash -c "pkill opendkim && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/opendkim'"
