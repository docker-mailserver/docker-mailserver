#!/bin/bash

# shellcheck disable=SC2291 # Quote repeated SPACE to avoid them collapsing into one.
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
# is missing. Both failures will result in exit code '1'.
function _log() {
  if [[ ! -v 1 ]]; then
    _log 'error' "Call to '_log' is missing a valid log level"
    return 1
  fi

  if [[ ! -v 2 ]]; then
    _log 'error' "Call to '_log' is missing a message to log"
    return 1
  fi

  local LEVEL_AS_INT LEVEL_STRING_WITH_COLOR SPACE MESSAGE

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
      LEVEL_STRING_WITH_COLOR+="${CYAN}TRACE"
      ;;

    ( 'debug' )
      [[ ${LEVEL_AS_INT} -ge 4 ]] || return 0
      LEVEL_STRING_WITH_COLOR+="${PURPLE}DEBUG"
      ;;

    ( 'info' )
      [[ ${LEVEL_AS_INT} -ge 3 ]] || return 0
      LEVEL_STRING_WITH_COLOR+="${BLUE}INFO "
      ;;

    ( 'warn' )
      [[ ${LEVEL_AS_INT} -ge 2 ]] || return 0
      LEVEL_STRING_WITH_COLOR+="${LYELLOW}WARN "
      ;;

    ( 'error' )
      [[ ${LEVEL_AS_INT} -ge 1 ]] || return 0
      LEVEL_STRING_WITH_COLOR+="${LRED}ERROR"
      ;;

    ( * )
      _log 'error' "Call to '_log' with invalid log level argument '${1}'"
      return 1
      ;;
  esac

  LEVEL_STRING_WITH_COLOR+="${RESET}"
  MESSAGE="$(date +'%Y-%m-%dT%H:%M:%S%:z')  ${LEVEL_STRING_WITH_COLOR}  ${2}"

  if [[ ${1} =~ ^(warn|error)$ ]]; then
    echo -e "${MESSAGE}" >&2
  else
    echo -e "${MESSAGE}"
  fi
}

# Get the value of the environment variable LOG_LEVEL if
# it is set. Otherwise, try to query the common environment
# variables file. If this does not yield a value either,
# use the default log level.
function _get_log_level_or_default() {
  if [[ -v LOG_LEVEL ]]; then
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
