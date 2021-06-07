#! /bin/bash

# version   v0.2.0 unstable
# executed  by Make during CI or manually
# task      checks files against linting targets

SCRIPT="lint.sh"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(realpath "${SCRIPT_DIR}"/../../)"

HADOLINT_VERSION=2.4.1
ECLINT_VERSION=2.3.5
SHELLCHECK_VERSION=0.7.2

set -eEuo pipefail
trap '__log_err "${FUNCNAME[0]:-?}" "${BASH_COMMAND:-?}" ${LINENO:-?} ${?:-?}' ERR

function __log_err
{
  printf "\n--- \e[1m\e[31mUNCHECKED ERROR\e[0m\n%s\n%s\n%s\n%s\n\n" \
    "  - script    = ${SCRIPT:-${0}}" \
    "  - function  = ${1} / ${2}" \
    "  - line      = ${3}" \
    "  - exit code = ${4}"
}

function __log_info
{
  printf "\n--- \e[34m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT:-${0}}" \
    "  - type    = INFO" \
    "  - version = ${*}"
}

function __log_failure
{
  printf "\n--- \e[91m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT:-${0}}" \
    "  - type    = FAILURE" \
    "  - message = ${*:-errors encountered}"
}

function __log_success
{
  printf "\n--- \e[32m%s\e[0m\n%s\n%s\n\n" \
    "${SCRIPT}" \
    "  - type    = SUCCESS" \
    "  - message = no errors detected"
}

function __in_path
{
  command -v "${@}" &>/dev/null && return 0 ; return 1 ;
}

function _eclint
{
  local SCRIPT='EDITORCONFIG LINTER'

  if docker run --rm --tty \
      --volume "${REPO_ROOT}:/ci:ro" \
      --workdir "/ci" \
      --name eclint \
      "mstruebing/editorconfig-checker:${ECLINT_VERSION}" ec -config "/ci/test/linting/.ecrc.json"
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

  if docker run --rm --tty \
      --volume "${REPO_ROOT}:/ci:ro" \
      --workdir "/ci" \
      "hadolint/hadolint:v${HADOLINT_VERSION}-alpine" hadolint --config "/ci/test/linting/.hadolint.yaml" Dockerfile
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
  
  # File paths for shellcheck:
  F_SH="$(find . -type f -iname '*.sh' \
    -not -path './test/bats/*' \
    -not -path './test/test_helper/*' \
    -not -path './target/docker-configomat/*'
  )"
  # macOS lacks parity for `-executable` but presently produces the same results: https://stackoverflow.com/a/4458361
  [[ "$(uname)" == "Darwin" ]] && FIND_EXEC="-perm +111 -type l -or" || FIND_EXEC="-executable"
  # shellcheck disable=SC2248
  F_BIN="$(find 'target/bin' ${FIND_EXEC} -type f)"
  F_BATS="$(find 'test' -maxdepth 1 -type f -iname '*.bats')"

  # This command is a bit easier to grok as multi-line. There is a `.shellcheckrc` file, but it's only supports half of the options below, thus kept as CLI:
  CMD_SHELLCHECK=(shellcheck 
    --external-sources 
    --check-sourced
    --severity=style
    --color=auto
    --wiki-link-count=50
    --enable=all
    --exclude=SC2154
    --source-path=SCRIPTDIR
    "${F_SH} ${F_BIN} ${F_BATS}"
  )
  
  # shellcheck disable=SC2068
  if docker run --rm --tty \
      --volume "${REPO_ROOT}:/ci:ro" \
      --workdir "/ci" \
      "koalaman/shellcheck-alpine:v${SHELLCHECK_VERSION}" ${CMD_SHELLCHECK[@]}
  then
    __log_success
  else
    __log_failure
    return 1
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

__main "${@}" || exit ${?}
