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

# Process matching notes:
# opendkim (/usr/sbin/opendkim) - x2 of the same process are found running (1 is the parent)
# opendmarc (/usr/sbin/opendmarc)
# master (/usr/lib/postfix/sbin/master) - Postfix main process (Can take a few seconds running to be ready)
# NOTE: pgrep or pkill used with `--full` would also match `/usr/sbin/amavisd-new (master)`
#
# amavi (/usr/sbin/amavi) - Matches three processes, the main process is `/usr/sbin/amavisd-new (master)`
# NOTE: `amavisd-new` can only be matched with `--full`, regardless pkill would return `/usr/sbin/amavi`
#
# clamd (/usr/sbin/clamd)
# dovecot (/usr/sbin/dovecot)
# fetchmail (/usr/bin/fetchmail)
# fail2ban-server (/usr/bin/python3 /usr/bin/fail2ban-server) - Started by fail2ban-wrapper.sh
# postgrey (postgrey) - NOTE: This process lacks path information to match with `--full` in pgrep / pkill
# postsrsd (/usr/sbin/postsrsd) - NOTE: Also matches the wrapper: `/bin/bash /usr/local/bin/postsrsd-wrapper.sh`
# saslauthd (/usr/sbin/saslauthd) - x5 of the same process are found running (1 is a parent of 4)

# Delays:
# (An old process may still be running: `pkill -e opendkim && sleep 3 && pgrep -a --older 5 opendkim`)
# dovecot + fail2ban, take approx 1 sec to kill properly
# opendkim + opendmarc can take up to 6 sec to kill properly
# clamd + postsrsd sometimes take 1-3 sec to restart after old process is killed.
# postfix + fail2ban (due to Wrapper scripts) can delay a restart by up to 5 seconds from usage of sleep.

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
  local MIN_PROCESS_AGE=4

  # Wait until process has been running for at least MIN_PROCESS_AGE:
  # (this allows us to more confidently check the process was restarted)
  run_until_success_or_timeout 30 _check_if_process_is_running "${PROCESS}" "${MIN_PROCESS_AGE}"
  # NOTE: refute_output doesn't have output to work with on timeout failure
  # refute_output --partial 'is not running'
  assert_success

  # Should kill the process successfully:
  # (which should then get restarted by supervisord)
  _run_in_container pkill --echo "${PROCESS}"
  assert_output --partial "${PROCESS}"
  assert_success

  # Wait until original process is not running:
  # (Ignore restarted process by filtering with MIN_PROCESS_AGE, --fatal-test with `false` stops polling on error):
  run repeat_until_success_or_timeout --fatal-test "_check_if_process_is_running ${PROCESS} ${MIN_PROCESS_AGE}" 30 false
  assert_output --partial 'is not running'
  assert_failure

  # Should be running:
  # (poll as some processes a slower to restart, such as those run by wrapper scripts adding delay via sleep)
  run_until_success_or_timeout 30 _check_if_process_is_running "${PROCESS}"
  # refute_output --partial 'is not running'
  assert_success
}

# NOTE: CONTAINER_NAME is implicit; it should have be set prior to calling.
function _check_if_process_is_running() {
  local PROCESS=${1}
  local MIN_SECS_RUNNING
  [[ -n ${2} ]] && MIN_SECS_RUNNING="--older ${2}"

  local IS_RUNNING=$(docker exec "${CONTAINER_NAME}" pgrep --list-full ${MIN_SECS_RUNNING} "${PROCESS}")

  # When no matches are found, nothing is returned. Provide something we can assert on (helpful for debugging):
  if [[ ! ${IS_RUNNING} =~ "${PROCESS}" ]]
  then
    echo "'${PROCESS}' is not running"
    return 1
  fi
}
