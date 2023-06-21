#!/bin/bash

# shellcheck disable=SC2291 # Quote repeated spaces to avoid them collapsing into one.
# shellcheck disable=SC2034 # VAR appears unused.

# Color variables for global usage
RED=$(echo -ne     '\e[0;31m')
GREEN=$(echo -ne   '\e[0;32m')
YELLOW=$(echo -ne  '\e[0;33m')
BLUE=$(echo -ne    '\e[0;34m')
PURPLE=$(echo -ne  '\e[0;35m')
CYAN=$(echo -ne    '\e[0;36m')
WHITE=$(echo -ne   '\e[0;37m')

# Light/bold variants
LRED=$(echo -ne    '\e[1;31m')
LGREEN=$(echo -ne  '\e[1;32m')
LYELLOW=$(echo -ne '\e[1;33m')
LBLUE=$(echo -ne   '\e[1;34m')
LPURPLE=$(echo -ne '\e[1;35m')
LCYAN=$(echo -ne   '\e[1;36m')
LWHITE=$(echo -ne  '\e[1;37m')

ORANGE=$(echo -ne  '\e[38;5;214m')
RESET=$(echo -ne   '\e[0m')

# ### DMS Logging Functionality
#
# This function provides the logging for scripts used by DMS.
# It adheres to the convention for log levels.
# Valid values (in order of increasing verbosity) are: `error`,
# `warn`, `info`, `debug` and `trace`. The default log level
# is `info`.
#
# #### Arguments
#
# $1 :: the log level to log the message with
# $2 :: the message
#
# #### Panics
#
# If the first argument is not set or invalid, an error
# message is logged. Likewise when the second argument
# is missing. Both failures will return with exit code '1'.
function _log() {
  if [[ -z ${1+set} ]]; then
    _log 'error' "Call to '_log' is missing a valid log level"
    return 1
  fi

  if [[ -z ${2+set} ]]; then
    _log 'error' "Call to '_log' is missing a message to log"
    return 1
  fi

  local LEVEL_AS_INT
  local MESSAGE="${RESET}["

  case "$(_get_log_level_or_default)" in
    ( 'trace' ) LEVEL_AS_INT=5 ;;
    ( 'debug' ) LEVEL_AS_INT=4 ;;
    ( 'warn'  ) LEVEL_AS_INT=2 ;;
    ( 'error' ) LEVEL_AS_INT=1 ;;
    ( *       ) LEVEL_AS_INT=3 ;;
  esac

  case "${1}" in
    ( 'trace' )
      [[ ${LEVEL_AS_INT} -ge 5 ]] || return 0
      MESSAGE+="  ${CYAN}TRACE  "
      ;;

    ( 'debug' )
      [[ ${LEVEL_AS_INT} -ge 4 ]] || return 0
      MESSAGE+="  ${PURPLE}DEBUG  "
      ;;

    ( 'info' )
      [[ ${LEVEL_AS_INT} -ge 3 ]] || return 0
      MESSAGE+="   ${BLUE}INF   "
      ;;

    ( 'warn' )
      [[ ${LEVEL_AS_INT} -ge 2 ]] || return 0
      MESSAGE+=" ${LYELLOW}WARNING "
      ;;

    ( 'error' )
      [[ ${LEVEL_AS_INT} -ge 1 ]] || return 0
      MESSAGE+="  ${LRED}ERROR  " ;;

    ( * )
      _log 'error' "Call to '_log' with invalid log level argument '${1}'"
      return 1
      ;;
  esac

  MESSAGE+="${RESET}]  ${2}"

  if [[ ${1} =~ ^(warn|error)$ ]]; then
    echo -e "${MESSAGE}" >&2
  else
    echo -e "${MESSAGE}"
  fi
}

# Like `_log` but adds a timestamp in front of the message.
function _log_with_date() {
  _log "${1}" "$(date '+%Y-%m-%d %H:%M:%S')  ${2}"
}

# Get the value of the environment variable LOG_LEVEL if
# it is set. Otherwise, try to query the common environment
# variables file. If this does not yield a value either,
# use the default log level.
function _get_log_level_or_default() {
  if [[ -n ${LOG_LEVEL+set} ]]; then
    echo "${LOG_LEVEL}"
  elif [[ -e /etc/dms-settings ]] && grep -q -E "^LOG_LEVEL='[a-z]+'" /etc/dms-settings; then
    grep '^LOG_LEVEL=' /etc/dms-settings | cut -d "'" -f 2
  else
    echo 'info'
  fi
}

# This function checks whether the log level is the one
# provided as the first argument.
function _log_level_is() {
  [[ $(_get_log_level_or_default) =~ ^${1}$ ]]
}
