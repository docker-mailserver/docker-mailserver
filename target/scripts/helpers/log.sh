#! /bin/bash

LOG_RESET='\e[0m'
LOG_LGRAY='\e[37m'
LOG_LBLUE='\e[94m'
LOG_BLUE='\e[34m'
LOG_LYELLOW='\e[93m'
LOG_RED='\e[91m'

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
# $1  :: the log level to log the message with
# $2+ :: the message
#
# #### Panics
#
# If the first argument is not set or invalid, an error
# message is logged. Likewise when the second argument
# is missing. Both failures will return with exit code '1'.
function _notify
{
  if [[ -z ${1+set} ]]
  then
    echo "Call to '_notify' is missing a valid log level" >&2
    return 1
  fi

  if [[ -z ${2+set} ]]
  then
    echo "Call to '_notify' is missing a message to log" >&2
    return 1
  fi

  local MESSAGE LEVEL_AS_INT
  MESSAGE="${LOG_RESET}["

  case "${LOG_LEVEL:-}" in
    ( 'trace'  ) LEVEL_AS_INT=5 ;;
    ( 'debug'  ) LEVEL_AS_INT=4 ;;
    ( 'warn'   ) LEVEL_AS_INT=2 ;;
    ( 'error'  ) LEVEL_AS_INT=1 ;;
    ( *        ) LEVEL_AS_INT=3 ;;
  esac

  case "${1}" in
    ( 'trace' )
      [[ ${LEVEL_AS_INT} -ge 5 ]] || return 0
      MESSAGE+="  ${LOG_LGRAY}TRACE  "
      ;;

    ( 'debug' )
      [[ ${LEVEL_AS_INT} -ge 4 ]] || return 0
      MESSAGE+="  ${LOG_LBLUE}DEBUG  "
      ;;

    ( 'info' )
      [[ ${LEVEL_AS_INT} -ge 3 ]] || return 0
      MESSAGE+="   ${LOG_BLUE}INF   "
      ;;

    ( 'warn' )
      [[ ${LEVEL_AS_INT} -ge 2 ]] || return 0
      MESSAGE+=" ${LOG_LYELLOW}WARNING "
      ;;

    ( 'error' )
      [[ ${LEVEL_AS_INT} -ge 1 ]] || return 0
      MESSAGE+="  ${LOG_RED}ERROR  " ;;

    ( * )
      echo "Call to '_notify' with invalid log level argument '${1}'" >&2
      return 1
      ;;
  esac

  shift 1
  MESSAGE+="${LOG_RESET}]  ${*}"

  echo -e "${MESSAGE}"
  return 0
}
