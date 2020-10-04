#!/usr/bin/env bash

# version   v0.1.0 stable
# executed  by TravisCI / manually
# task      checks files agains linting targets

SCRIPT="LINT TESTS"

function _get_current_directory
{
  if dirname "$(readlink -f "${0}")" &>/dev/null
  then
    CDIR="$(cd "$(dirname "$(readlink -f "${0}")")" && pwd)"
  elif realpath -e -L "${0}" &>/dev/null
  then
    CDIR="$(realpath -e -L "${0}")"
    CDIR="${CDIR%/setup.sh}"
  fi
}

CDIR="$(pwd)"
_get_current_directory

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

  if "${LINT[@]}"
  then
    __log_success 'no errors detected'
  else
    __log_abort
    return 101
  fi
}

function _hadolint
{
  local LINT=(hadolint -c "${CDIR}/.hadolint.yaml")

  if ! __in_path "${LINT[0]}"
  then
    __log_abort 'linter not in PATH'
    return 102
  fi

  __log_info \
    'starting editorconfig linting' \
    '(linter version:' "$(${LINT[0]} --version))"

  if git ls-files --exclude='Dockerfile*' --ignored | \
    xargs --max-lines=1 "${LINT[@]}"
  then
    __log_success 'no errors detected'
  else
    __log_abort
    return 101
  fi
}

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

  local FIND=(
    find . -iname "*.sh"
    -not -path "./test/*"
    -not -path "./target/docker-configomat/*"
    -exec "${LINT[@]}" {} \;)

  if "${FIND[@]}" | grep -q .
  then
    "${FIND[@]}"
    __log_abort
    return 101
  else
    __log_success 'no errors detected'
  fi
}

function _main
{
  case ${1:- } in
    'eclint'      ) _eclint     ;;
    'hadolint'    ) _hadolint   ;;
    'shellcheck'  ) _shellcheck ;;
    *)
      __log_abort \
        "init.sh: '${1}' is not a command nor an option. See 'make help'."
      exit 11
      ;;
  esac
}

_main "${@}" || exit ${?}
