#! /bin/bash

# version   v0.2.0 unstable
# executed  by Make during CI or manually
# task      checks files against linting targets

SCRIPT="lint.sh"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(realpath "${SCRIPT_DIR}"/../../)"

KERNEL_NAME=$(uname -s)
KERNEL_NAME_LOWERCASE=$(echo "${KERNEL_NAME}" | tr '[:upper:]' '[:lower:]')
MACHINE_ARCH=$(uname -m)

SHELLCHECK_VERSION="0.7.2"
ECLINT_VERSION="2.3.5"

set -eEuo pipefail
trap '__log_err "${FUNCNAME[0]:-?}" "${BASH_COMMAND:-?}" ${LINENO:-?} ${?:-?}' ERR

function __log_err
{
  printf "\n––– \e[1m\e[31mUNCHECKED ERROR\e[0m\n%s\n%s\n%s\n%s\n\n" \
    "  – script    = ${SCRIPT:-${0}}" \
    "  – function  = ${1} / ${2}" \
    "  – line      = ${3}" \
    "  – exit code = ${4}"
}

function __log_info
{
  printf "\n––– \e[34m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT:-${0}}" \
    "  – type    = INFO" \
    "  – version = ${*}"
}

function __log_failure
{
  printf "\n––– \e[91m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT:-${0}}" \
    "  – type    = FAILURE" \
    "  – message = ${*:-errors encountered}"
}

function __log_success
{
  printf "\n––– \e[32m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT}" \
    "  – type    = SUCCESS" \
    "  – message = no errors detected"
}

function __in_path
{
  command -v "${@}" &>/dev/null && return 0 ; return 1 ;
}

function _eclint
{
  local SCRIPT='EDITORCONFIG LINTER'

  local IGNORE='.*\.git.*|.*\.md$|\.bats$|\.cf$|'
  IGNORE+='\.conf$|\.init$|.*test/.*|.*tools/.*'

  local LINT=(
    eclint
    -config
    "${REPO_ROOT}/test/linting/.ecrc.json"
    -exclude
    "(${IGNORE})"
  )

  if ! __in_path "${LINT[0]}"
  then
    __log_info 'linter not in PATH... Downloading...'
    mkdir -p "${REPO_ROOT}/tools"
    curl -s -S -L \
      "https://github.com/editorconfig-checker/editorconfig-checker/releases/download/${ECLINT_VERSION}/ec-${KERNEL_NAME_LOWERCASE}-amd64.tar.gz" | \
      tar -zxO "bin/ec-${KERNEL_NAME_LOWERCASE}-amd64" > "${REPO_ROOT}/tools/eclint"
    chmod u+rx "${REPO_ROOT}/tools/eclint"
  fi

  __log_info "$(${LINT[0]} --version)"

  if "${LINT[@]}"
  then
    __log_success
  else
    __log_failure
    return 1
  fi
}

function _hadolint
{
  local SCRIPT='HADOLINT'
  local LINT=(hadolint -c "${REPO_ROOT}/test/linting/.hadolint.yaml")

  if ! __in_path "${LINT[0]}"
  then
    __log_failure 'linter not in PATH'
    return 2
  fi

  __log_info "$(${LINT[0]} --version | grep -E -o "v[0-9\.]*")"

  if "${LINT[@]}" Dockerfile
  then
    __log_success
  else
    __log_failure
    return 1
  fi
}

function _shellcheck
{
  local SCRIPT='SHELLCHECK'
  local ERR=0
  local LINT=(shellcheck -x -S style -Cauto -o all -e SC2154 -W 50)

  if ! __in_path "${LINT[0]}"
  then
    __log_info 'linter not in PATH... Downloading...'
    mkdir -p "${REPO_ROOT}/tools"
    curl -s -S -L \
		  "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.${KERNEL_NAME_LOWERCASE}.${MACHINE_ARCH}.tar.xz" | \
      tar -JxO "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" > "${REPO_ROOT}/tools/shellcheck"
    chmod u+rx "${REPO_ROOT}/tools/shellcheck"
  fi

  __log_info "$(${LINT[0]} --version | grep -m 2 -o "[0-9.]*")"

  # an overengineered solution to allow shellcheck -x to
  # properly follow `source=<SOURCE FILE>` when sourcing
  # files with `. <FILE>` in shell scripts.
  while read -r FILE
  do
    if ! (
      cd "$(realpath "$(dirname "$(readlink -f "${FILE}")")")"
      if ! "${LINT[@]}" "$(basename -- "${FILE}")"
      then
        exit 1
      fi
    )
    then
      ERR=1
    fi
  done < <(find . -type f -iname "*.sh" \
    -not -path "./test/bats/*" \
    -not -path "./test/test_helper/*" \
    -not -path "./target/docker-configomat/*")

  # the same for executables in target/bin/
  while read -r FILE
  do
    if ! (
      cd "$(realpath "$(dirname "$(readlink -f "${FILE}")")")"
      if ! "${LINT[@]}" "$(basename -- "${FILE}")"
      then
        exit 1
      fi
    )
    then
      ERR=1
    fi
  done < <(find target/bin -executable -type f)

  # the same for all test files
  while read -r FILE
  do
    if ! (
      cd "$(realpath "$(dirname "$(readlink -f "${FILE}")")")"
      if ! "${LINT[@]}" "$(basename -- "${FILE}")"
      then
        exit 1
      fi
    )
    then
      ERR=1
    fi
  done < <(find test/ -maxdepth 1 -type f -iname "*.bats")

  if [[ ${ERR} -eq 1 ]]
  then
    __log_failure 'errors encountered'
    return 1
  else
    __log_success
  fi
}

function __main
{
  case "${1:-}" in
    'eclint'      ) _eclint     ;;
    'hadolint'    ) _hadolint   ;;
    'shellcheck'  ) _shellcheck ;;
    *)
      __log_failure "'${1:-}' is not a command nor an option."
      return 3
      ;;
  esac
}

# prefer linters installed in tools
PATH="${REPO_ROOT}/tools:${PATH}"
export PATH

__main "${@}" || exit ${?}
