#!/usr/bin/env bash

# version   v0.1.0 stable
# executed  by TravisCI / manually
# task      checks files agains linting targets

SCRIPT="LINT TESTS"

# ? ––––––––––––––––––––––––––––––––––––––––––––– ERRORS

set -eEuo pipefail
trap '__log_err ${FUNCNAME[0]:-"?"} ${_:-"?"} ${LINENO:-"?"} ${?:-"?"}' ERR

function __log_err
{
  local FUNC_NAME LINE EXIT_CODE
  FUNC_NAME="${1} / ${2}"
  LINE="${3}"
  EXIT_CODE="${4}"

  printf "\n––– \e[1m\e[31mUNCHECKED ERROR\e[0m\n%s\n%s\n%s\n%s\n\n" \
    "  – script    = ${SCRIPT}" \
    "  – function  = ${FUNC_NAME}" \
    "  – line      = ${LINE}" \
    "  – exit code = ${EXIT_CODE}"

  unset CDIR SCRIPT OS VERSION
}

# ? ––––––––––––––––––––––––––––––––––––––––––––– LOG

function __log_info
{
  printf "\n––– \e[34m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT}" \
    "  – type    = INFO" \
    "  – message = ${*}"
}

function __log_warning
{
  printf "\n––– \e[93m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT}" \
    "  – type    = WARNING" \
    "  – message = ${*}"
}

function __log_abort
{
  printf "\n––– \e[91m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT}" \
    "  – type    = ABORT" \
    "  – message = ${*:-"errors encountered"}"
}

function __log_success
{
  printf "\n––– \e[32m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT}" \
    "  – type    = SUCCESS" \
    "  – message = ${*}"
}

function __in_path { __which "${@}" && return 0 ; return 1 ; }
function __which { command -v "${@}" &>/dev/null ; }

function _shellcheck
{
  local LINT=(/usr/bin/shellcheck -S style -Cauto -o all -e SC2154 -W 50)

  if ! __in_path "${LINT[0]}"
  then
    __log_abort 'linter not in PATH'
    return 102
  fi

  __log_info \
    'starting shellcheck' '(linter version:' \
    "$(${LINT[0]} --version | grep -m 2 -o "[0-9.]*"))"

  if find . -iname "*.sh" -not -path "./test/*" -not -path "./target/docker-configomat/*" -exec /usr/bin/shellcheck -S style -Cauto -o all -e SC2154 -W 50 {} \; | grep .
  then
    find . \( -iname "*.bash" -o -iname "*.sh" \) -exec "${LINT[@]}" {} \;
    __log_abort
    return 101
  else
    __log_success 'no errors detected'
  fi
}

function _eclint
{
  local LINT=(eclint -exclude "(.*\.git.*|.*\.md$|\.bats$)")

  if ! __in_path "${LINT[0]}"
  then
    __log_abort 'linter not in PATH'
    return 102
  fi

  __log_info \
    'starting editorconfig linting' \
    '(linter version:' "$(${LINT[0]} --version))"

  if "${LINT[@]}" | grep . &>/dev/null
  then
    printf ' \n' && "${LINT[@]}"
    __log_abort
    return 101
  else
    __log_success 'no errors detected'
  fi
}

function _main
{
  case ${1:- } in
    'shellcheck'  ) _shellcheck ;;
    'eclint'      ) _eclint     ;;
    *)
      __log_abort \
        "init.sh: '${1}' is not a command nor an option. See 'make help'."
      exit 11
      ;;
  esac
}

_main "${@}" || exit ${?}
