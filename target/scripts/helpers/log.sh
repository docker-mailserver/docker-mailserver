#! /bin/bash

function _notify
{
  { [[ -z ${1:-} ]] || [[ -z ${2:-} ]] ; } && return 1

  local RESET='\e[0m'
  local LGRAY='\e[37m'
  local LBLUE='\e[94m'
  local BLUE='\e[34m'
  local LYELLOW='\e[93m'
  local RED='\e[91m'

  local MESSAGE LEVEL_AS_INT
  MESSAGE="${RESET}["

  case "${LOG_LEVEL}" in
    ( 'trace' ) LEVEL_AS_INT=4 ;;
    ( 'debug' ) LEVEL_AS_INT=3 ;;
    ( 'info' )  LEVEL_AS_INT=2 ;;
    ( 'warn' )  LEVEL_AS_INT=1 ;;
    ( 'error' ) LEVEL_AS_INT=0 ;;
  esac

  case "${1}" in
    ( 'trace' )
      [[ ${LEVEL_AS_INT} -ge 4 ]] || return 0
      MESSAGE+="  ${LGRAY}TRACE  "
      ;;

    ( 'debug' )
      [[ ${LEVEL_AS_INT} -ge 3 ]] || return 0
      MESSAGE+="  ${LBLUE}DEBUG  "
      ;;

    ( 'info' )
      [[ ${LEVEL_AS_INT} -ge 2 ]] || return 0
      MESSAGE+="   ${BLUE}INF   "
      ;;

    ( 'warn' )
      [[ ${LEVEL_AS_INT} -ge 1 ]] || return 0
      MESSAGE+=" ${LYELLOW}WARNING "
      ;;

    ( 'always' )
      MESSAGE+="         "
      ;;

    ( * ) MESSAGE+="  ${RED}ERROR  " ;;
  esac

  shift 1
  MESSAGE+="${RESET}]  |  ${*}"

  echo -e "${MESSAGE}"
  return 0
}
