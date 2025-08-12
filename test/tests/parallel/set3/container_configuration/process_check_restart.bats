load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Process Management] '
CONTAINER1_NAME='dms-test_process-check-restart_disabled'
CONTAINER2_NAME='dms-test_process-check-restart_enabled'
CONTAINER3_NAME='dms-test_process-check-restart_clamav'

function teardown() { _default_teardown ; }

# Process matching notes:
# opendkim (/usr/sbin/opendkim) - x2 of the same process are found running (1 is the parent)
# opendmarc (/usr/sbin/opendmarc)
# postfix (/usr/lib/postfix/sbin/master) - Postfix main process (two ancestors, launched via pidproxy python3 script)
#
# amavisd (usr/sbin/amavisd)
# clamd (/usr/sbin/clamd)
# dovecot (/usr/sbin/dovecot)
# fetchmail (/usr/bin/fetchmail)
# fail2ban-server (/usr/bin/python3 /usr/bin/fail2ban-server) - NOTE: python3 is due to the shebang
# getmail (/bin/bash /usr/local/bin/getmail-service.sh)
# mta-sts-daemon (/usr/bin/bin/python3 /usr/bin/mta-sts-daemon)
# postgrey (postgrey) - NOTE: This process command uses perl via shebang, but unlike python3 the context is missing
# postsrsd (/usr/sbin/postsrsd)
# saslauthd (/usr/sbin/saslauthd) - x5 of the same process are found running (1 is a parent of 4)

# Delays:
# (An old process may still be running: `pkill -e opendkim && sleep 3 && pgrep -a --older 5 opendkim`)
# dovecot + fail2ban, take approx 1 sec to kill properly
# opendkim + opendmarc can take up to 6 sec to kill properly
# clamd + postsrsd sometimes take 1-3 sec to restart after old process is killed.

# These processes should always be running:
CORE_PROCESS_LIST=(
  postfix
)

# These processes can be toggled via ENV:
# NOTE: clamd handled in separate test case
ENV_PROCESS_LIST=(
  amavisd
  dovecot
  fail2ban-server
  fetchmail
  getmail
  mta-sts-daemon
  opendkim
  opendmarc
  postgrey
  postsrsd
  saslauthd
)

@test "(disabled ENV) should only run expected processes" {
  export CONTAINER_NAME=${CONTAINER1_NAME}
  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env ENABLE_AMAVIS=0
    --env ENABLE_CLAMAV=0
    --env ENABLE_FAIL2BAN=0
    --env ENABLE_FETCHMAIL=0
    --env ENABLE_GETMAIL=0
    --env ENABLE_MTA_STS=0
    --env ENABLE_OPENDKIM=0
    --env ENABLE_OPENDMARC=0
    --env ENABLE_POSTGREY=0
    --env ENABLE_SASLAUTHD=0
    --env ENABLE_SRS=0
    # Disable Dovecot:
    --env SMTP_ONLY=1
  )
  _init_with_defaults
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  # Required for Postfix (when launched by wrapper script which is slow to start)
  _wait_for_smtp_port_in_container

  for PROCESS in "${CORE_PROCESS_LIST[@]}"; do
    run _check_if_process_is_running "${PROCESS}"
    assert_success
    assert_output --partial "${PROCESS}"
    refute_output --partial "is not running"
  done

  for PROCESS in "${ENV_PROCESS_LIST[@]}" clamd; do
    run _check_if_process_is_running "${PROCESS}"
    assert_failure
    assert_output --partial "'${PROCESS}' is not running"
  done
}

# Average time: 23 seconds
@test "(enabled ENV) should restart processes when killed" {
  export CONTAINER_NAME=${CONTAINER2_NAME}
  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_FAIL2BAN=1
    --env ENABLE_FETCHMAIL=1
    --env ENABLE_GETMAIL=1
    --env ENABLE_MTA_STS=1
    --env ENABLE_OPENDKIM=1
    --env ENABLE_OPENDMARC=1
    --env FETCHMAIL_PARALLEL=1
    --env ENABLE_POSTGREY=1
    --env ENABLE_SASLAUTHD=1
    --env ENABLE_SRS=1
    --env SMTP_ONLY=0
    # Required workaround for some environments when using ENABLE_SRS=1:
    # PR 2730: https://github.com/docker-mailserver/docker-mailserver/commit/672e9cf19a3bb1da309e8cea6ee728e58f905366
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  mv "${TEST_TMP_CONFIG}/fetchmail/fetchmail.cf" "${TEST_TMP_CONFIG}/fetchmail.cf"
  # Average time: 6 seconds
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  local ENABLED_PROCESS_LIST=(
    "${CORE_PROCESS_LIST[@]}"
    "${ENV_PROCESS_LIST[@]}"
  )

  for PROCESS in "${ENABLED_PROCESS_LIST[@]}"; do
    _should_restart_when_killed "${PROCESS}"
  done

  # By this point the fetchmail processes have been verified to exist and restart,
  # For FETCHMAIL_PARALLEL=1 coverage, match full commandline for COUNTER values:
  _run_in_container pgrep --full 'fetchmail-1.rc'
  assert_success
  _run_in_container pgrep --full 'fetchmail-2.rc'
  assert_success

  _should_stop_cleanly
}

# Split into separate test case for the benefit of minimizing CPU + RAM overhead of clamd.
# NOTE: Does not reduce test time of previous test case. Adds 10 seconds to test time.
@test "(enabled ENV) should restart clamd when killed" {
  export CONTAINER_NAME=${CONTAINER3_NAME}
  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env ENABLE_CLAMAV=1
  )
  _init_with_defaults
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  _should_restart_when_killed 'clamd'
  _should_stop_cleanly
}

function _should_restart_when_killed() {
  local PROCESS=${1}
  local MIN_PROCESS_AGE=4

  # Wait until process has been running for at least MIN_PROCESS_AGE:
  # (this allows us to more confidently check the process was restarted)
  _run_until_success_or_timeout 30 _check_if_process_is_running "${PROCESS}" "${MIN_PROCESS_AGE}"
  # NOTE: refute_output will not have any output to compare against if a `run` failure is caused by a timeout
  assert_success
  assert_output --partial "${PROCESS}"

  # Should kill the process successfully:
  # (which should then get restarted by supervisord)
  # NOTE: The process name from `pkill --echo` does not always match the equivalent process name from `pgrep --list-full`.
  # The oldest process returned (if multiple) should be the top-level process launched by supervisord,
  # the PID will verify the target process was killed correctly:
  local PID=$(_exec_in_container pgrep --full --oldest "${PROCESS}")
  _run_in_container pkill --echo --full "${PROCESS}"
  assert_output --partial "killed (pid ${PID})"
  assert_success

  # Wait until original process is not running:
  # (Ignore restarted process by filtering with MIN_PROCESS_AGE, --fatal-test with `false` stops polling on error):
  run _repeat_until_success_or_timeout --fatal-test "_check_if_process_is_running ${PROCESS} ${MIN_PROCESS_AGE}" 30 false
  assert_output --partial "'${PROCESS}' is not running"
  assert_failure

  # Should be running:
  # (poll as some processes a slower to restart, such as those run by wrapper scripts adding delay via sleep)
  _run_until_success_or_timeout 30 _check_if_process_is_running "${PROCESS}"
  assert_success
  assert_output --partial "${PROCESS}"
}

# NOTE: CONTAINER_NAME is implicit; it should have been set prior to calling.
function _check_if_process_is_running() {
  local PROCESS=${1}
  local MIN_SECS_RUNNING
  [[ -n ${2:-} ]] && MIN_SECS_RUNNING=('--older' "${2}")

  # `--list-full` provides information for matching against (full process path)
  # `--full` allows matching the process against the full path (required if a process is not the exec command, such as started by python3 command without a shebang)
  # `--oldest` should select the parent process when there are multiple results, typically the command defined in `dms-services.conf`
  local IS_RUNNING=$(_exec_in_container pgrep --full --list-full "${MIN_SECS_RUNNING[@]}" --oldest "${PROCESS}")

  # When no matches are found, nothing is returned. Provide something we can assert on (helpful for debugging):
  if [[ ! ${IS_RUNNING} =~ ${PROCESS} ]]; then
    echo "'${PROCESS}' is not running"
    return 1
  fi

  # Original output (if any) for assertions
  echo "${IS_RUNNING}"
}

# The process manager (supervisord) should perform a graceful shutdown:
# NOTE: Time limit should never be below these configured values:
# - dms-services.conf:stopwaitsecs
# - compose.yaml:stop_grace_period
function _should_stop_cleanly() {
  run docker stop -t 60 "${CONTAINER_NAME}"
  assert_success

  # Running `docker rm -f` too soon after `docker stop` can result in failure during teardown with:
  # "Error response from daemon: removal of container "${CONTAINER_NAME}" is already in progress"
  sleep 1
}
