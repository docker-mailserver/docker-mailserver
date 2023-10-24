#!/bin/bash

# version   v0.3.0
# executed  by Make (during CI or manually)
# task      checks files against linting targets

set -eEuo pipefail
shopt -s inherit_errexit

REPOSITORY_ROOT=$(realpath "$(dirname "$(readlink -f "${0}")")"/../../)
LOG_LEVEL=${LOG_LEVEL:-debug}
HADOLINT_VERSION='2.12.0'
ECLINT_VERSION='2.7.2'
SHELLCHECK_VERSION='0.9.0'

# shellcheck source=./../../target/scripts/helpers/log.sh
source "${REPOSITORY_ROOT}/target/scripts/helpers/log.sh"

function _eclint() {
  if docker run --rm --tty \
    --volume "${REPOSITORY_ROOT}:/ci:ro" \
    --workdir "/ci" \
    --name dms-test_eclint \
    "mstruebing/editorconfig-checker:${ECLINT_VERSION}" ec -config "/ci/test/linting/.ecrc.json"
  then
    _log 'info' 'ECLint succeeded'
  else
    _log 'error' 'ECLint failed'
    return 1
  fi
}

function _hadolint() {
  if docker run --rm --tty \
    --volume "${REPOSITORY_ROOT}:/ci:ro" \
    --workdir "/ci" \
    --name dms-test_hadolint \
    "hadolint/hadolint:v${HADOLINT_VERSION}-alpine" hadolint --config "/ci/test/linting/.hadolint.yml" Dockerfile
  then
    _log 'info' 'Hadolint succeeded'
  else
    _log 'error' 'Hadolint failed'
    return 1
  fi
}

# Create three arrays (F_SH, F_BIN, F_BATS) containing our BASH scripts
function _getBashScripts() {
  readarray -d '' F_SH < <(find . -type f -iname '*.sh' \
    -not -path './test/bats/*' \
    -not -path './test/test_helper/*' \
    -not -path './.git/*' \
    -print0 \
  )

  # shellcheck disable=SC2248
  readarray -d '' F_BIN < <(find 'target/bin' -type f -not -name '*.py' -print0)
  readarray -d '' F_BATS < <(find 'test/tests/' -type f -iname '*.bats' -print0)
}

# Check BASH files for correct syntax
function _bashcheck() {
  local ERROR=0 SCRIPT
  # .bats files are excluded from the test below: Due to their custom syntax ( @test ), .bats files are not standard bash
  for SCRIPT in "${F_SH[@]}" "${F_BIN[@]}"; do
    bash -n "${SCRIPT}" || ERROR=1
  done

  if [[ ${ERROR} -eq 0 ]]; then
    _log 'info' 'BASH syntax check succeeded'
  else
    _log 'error' 'BASH syntax check failed'
    return 1
  fi
}

function _shellcheck() {
  # This command is a bit easier to grok as multi-line.
  # There is a `.shellcheckrc` file, but it's only supports half of the options below, thus kept as CLI:
  # `SCRIPTDIR` is a special value that represents the path of the script being linted,
  # all sourced scripts share the same SCRIPTDIR source-path of the original script being linted.
  local CMD_SHELLCHECK=(shellcheck
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
  )

  local BATS_EXTRA_ARGS=(
    --exclude=SC2030
    --exclude=SC2031
    --exclude=SC2034
    --exclude=SC2155
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
  local ERROR=0

  docker run --rm --tty \
    --volume "${REPOSITORY_ROOT}:/ci:ro" \
    --workdir "/ci" \
    --name dms-test_shellcheck \
    "koalaman/shellcheck-alpine:v${SHELLCHECK_VERSION}" "${CMD_SHELLCHECK[@]}" "${F_SH[@]}" "${F_BIN[@]}" || ERROR=1

  docker run --rm --tty \
    --volume "${REPOSITORY_ROOT}:/ci:ro" \
    --workdir "/ci" \
    --name dms-test_shellcheck \
    "koalaman/shellcheck-alpine:v${SHELLCHECK_VERSION}" "${CMD_SHELLCHECK[@]}" \
    "${BATS_EXTRA_ARGS[@]}" "${F_BATS[@]}" || ERROR=1

  if [[ ${ERROR} -eq 0 ]]; then
    _log 'info' 'ShellCheck succeeded'
  else
    _log 'error' 'ShellCheck failed'
    return 1
  fi
}

function _main() {
  case "${1:-}" in
    ( 'eclint'     ) _eclint                      ;;
    ( 'hadolint'   ) _hadolint                    ;;
    ( 'bashcheck'  ) _getBashScripts; _bashcheck  ;;
    ( 'shellcheck' ) _getBashScripts; _shellcheck ;;
    ( * )
      _log 'error' "'${1:-}' is not a command nor an option"
      return 3
      ;;
  esac
}

_main "${@}" || exit ${?}
