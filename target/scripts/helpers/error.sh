#! /bin/bash

function _exit_with_error
{
  if [[ -n ${1+set} ]]
  then
    _log 'error' "${1}"
  else
    _log 'error' "Call to '_exit_with_error' is missing a message to log"
  fi

  _log 'error' 'Aborting'
  exit "${2:-1}"
}

# `dms_panic` methods are appropriate when the type of error is a not recoverable,
# or needs to be very clear to the user about misconfiguration.
#
# Method is called with args:
# PANIC_TYPE => (Internal value for matching). You should use the convenience methods below based on your panic type.
# PANIC_INFO => Provide your own message string to insert into the error message for that PANIC_TYPE.
# PANIC_SCOPE => Optionally provide a string for debugging to better identify/locate the source of the panic.
function dms_panic
{
  local PANIC_TYPE=${1}
  local PANIC_INFO=${2}
  local PANIC_SCOPE=${3} #optional

  local SHUTDOWN_MESSAGE

  case "${PANIC_TYPE:-}" in
    ( 'fail-init' ) # PANIC_INFO == <name of service or process that failed to start / initialize>
      SHUTDOWN_MESSAGE="Failed to start ${PANIC_INFO}!"
      ;;

    ( 'no-env' ) # PANIC_INFO == <ENV VAR name>
      SHUTDOWN_MESSAGE="Environment Variable: ${PANIC_INFO} is not set!"
      ;;

    ( 'no-file' ) # PANIC_INFO == <invalid filepath>
      SHUTDOWN_MESSAGE="File ${PANIC_INFO} does not exist!"
      ;;

    ( 'misconfigured' ) # PANIC_INFO == <something possibly misconfigured, eg an ENV var>
      SHUTDOWN_MESSAGE="${PANIC_INFO} appears to be misconfigured, please verify."
      ;;

    ( 'invalid-value' ) # PANIC_INFO == <an unsupported or invalid value, eg in a case match>
      SHUTDOWN_MESSAGE="Invalid value for ${PANIC_INFO}!"
      ;;

    ( * ) # `dms_panic` was called directly without a valid PANIC_TYPE
      SHUTDOWN_MESSAGE='Something broke :('
      ;;
  esac

  if [[ -n ${PANIC_SCOPE:-} ]]
  then
    _shutdown "${PANIC_SCOPE} | ${SHUTDOWN_MESSAGE}"
  else
    _shutdown "${SHUTDOWN_MESSAGE}"
  fi
}

# Convenience wrappers based on type:
function dms_panic__fail_init { dms_panic 'fail-init' "${1}" "${2}"; }
function dms_panic__no_env { dms_panic 'no-env' "${1}" "${2}"; }
function dms_panic__no_file { dms_panic 'no-file' "${1}" "${2}"; }
function dms_panic__misconfigured { dms_panic 'misconfigured' "${1}" "${2}"; }
function dms_panic__invalid_value { dms_panic 'invalid-value' "${1}" "${2}"; }

# Call this method when you want to panic (i.e. emit an 'ERROR' log, and exit uncleanly).
# `dms_panic` methods should be preferred if your failure type is supported.
function _shutdown
{
  _log 'error' "${1}"
  _log 'error' 'Shutting down'

  sleep 1
  kill 1
  exit 1
}
