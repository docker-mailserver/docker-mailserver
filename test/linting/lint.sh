#! /bin/bash

# version   v0.2.0 unstable
# executed  by Make during CI or manually
# task      checks files against linting targets

SCRIPT="lint.sh"

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
REPO_ROOT=$(realpath "${SCRIPT_DIR}"/../../)

HADOLINT_VERSION=2.8.0
ECLINT_VERSION=2.3.5
SHELLCHECK_VERSION=0.8.0

set -eEuo pipefail
shopt -s inherit_errexit
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
  F_SH=$(find . -type f -iname '*.sh' \
    -not -path './test/bats/*' \
    -not -path './test/test_helper/*' \
    -not -path './target/docker-configomat/*'
  )
  # shellcheck disable=SC2248
  F_BIN=$(find 'target/bin' -type f -not -name '*.py')
  F_BATS=$(find 'test' -maxdepth 1 -type f -iname '*.bats')

  # This command is a bit easier to grok as multi-line.
  # There is a `.shellcheckrc` file, but it's only supports half of the options below, thus kept as CLI:
  # `SCRIPTDIR` is a special value that represents the path of the script being linted,
  # all sourced scripts share the same SCRIPTDIR source-path of the original script being linted.
  CMD_SHELLCHECK=(shellcheck
    --external-sources
    --check-sourced
    --severity=style
    --color=auto
    --wiki-link-count=50
    --enable=all
    --exclude=SC2154
    --exclude=SC2310
    --exclude=SC2311
    --exclude=SC2312
    --source-path=SCRIPTDIR
    "${F_SH} ${F_BIN} ${F_BATS}"
  )

  # The linter can reference additional source-path values declared in scripts,
  # which in our case rarely benefit from extending from `SCRIPTDIR` and instead
  # should use a relative path from the project root (mounted at `/ci`), eg `target/scripts/`.
  # Note that `SCRIPTDIR` will strip a prefix variable for a source path, which can be useful
  # if `SCRIPTDIR` would always be the same value, and combined with relative path via another
  # `source-path=SCRIPTDIR/relative/path/to/scripts` in the .sh file.
  # These source-path values can apply to the entire file (and sourced files) if not wrapped in a function scope.
  # Otherwise it only applies to the line below it. You can declare multiple source-paths, they don't override the previous.
  # `source=relative/path/to/file.sh` will check the source value in each source-path as well.
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
