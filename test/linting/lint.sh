#!/bin/bash

# version   v0.3.0
# executed  by Make (during CI or manually)
# task      checks files against linting targets

set -eEuo pipefail
shopt -s inherit_errexit

REPOSITORY_ROOT=$(realpath "$(dirname "$(readlink -f "${0}")")"/../../)
LOG_LEVEL=${LOG_LEVEL:-debug}
HADOLINT_VERSION='2.9.2'
ECLINT_VERSION='2.4.0'
SHELLCHECK_VERSION='0.8.0'

# shellcheck source=./../../target/scripts/helpers/log.sh
source "${REPOSITORY_ROOT}/target/scripts/helpers/log.sh"

function _eclint
{
  if docker run --rm --tty \
    --volume "${REPOSITORY_ROOT}:/ci:ro" \
    --workdir "/ci" \
    --name eclint \
    "mstruebing/editorconfig-checker:${ECLINT_VERSION}" ec -config "/ci/test/linting/.ecrc.json"
  then
    _log 'info' 'ECLint succeeded'
  else
    _log 'error' 'ECLint failed'
    return 1
  fi
}

function _hadolint
{
  if docker run --rm --tty \
    --volume "${REPOSITORY_ROOT}:/ci:ro" \
    --workdir "/ci" \
    "hadolint/hadolint:v${HADOLINT_VERSION}-alpine" hadolint --config "/ci/test/linting/.hadolint.yaml" Dockerfile
  then
    _log 'info' 'Hadolint succeeded'
  else
    _log 'error' 'Hadolint failed'
    return 1
  fi
}

function _shellcheck
{
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
    --volume "${REPOSITORY_ROOT}:/ci:ro" \
    --workdir "/ci" \
    "koalaman/shellcheck-alpine:v${SHELLCHECK_VERSION}" ${CMD_SHELLCHECK[@]}
  then
    _log 'info' 'ShellCheck succeeded'
  else
    _log 'error' 'ShellCheck failed'
    return 1
  fi
}

function _main
{
  case "${1:-}" in
    ( 'eclint'     ) _eclint     ;;
    ( 'hadolint'   ) _hadolint   ;;
    ( 'shellcheck' ) _shellcheck ;;
    ( * )
      _log 'error' "'${1:-}' is not a command nor an option"
      return 3
      ;;
  esac
}

_main "${@}" || exit ${?}
