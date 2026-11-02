# AGENTS.md

Docker Mailserver (DMS) is a single-container mail server (Postfix, Dovecot, Rspamd, Amavis, ClamAV, Fail2Ban, ...). It is configured entirely through environment variables and a config volume mounted at `/tmp/docker-mailserver`. Nearly all logic is Bash.

## Layout

| Path | Purpose |
| :- | :- |
| `Dockerfile` | Image build; copies files from `target/` into the image |
| `target/scripts/start-mailserver.sh` | Container entrypoint; registers and runs check, setup, and daemon functions |
| `target/scripts/startup/` | `variables-stack.sh` (ENV defaults), `check-stack.sh`, `setup-stack.sh`, `daemons-stack.sh` |
| `target/scripts/startup/setup.d/` | Per-feature `_setup_*` functions, all sourced at startup |
| `target/scripts/helpers/` | Shared Bash helpers (logging, errors, Postfix, TLS, accounts, ...) |
| `target/scripts/check-for-changes.sh` | Change detector; reloads services when files in the config volume change |
| `target/bin/` | In-container commands (`setup` and its subcommands); `setup.sh` in the root wraps them via `docker exec` |
| `target/<service>/` | Static config files for each bundled service |
| `test/tests/{parallel,serial}/` | BATS integration tests |
| `test/helper/` | Test helpers; read their doc comments before writing tests |
| `docs/content/` | MkDocs Material sources (`docs/site/` is build output, do not edit) |
| `mailserver.env` | User-facing ENV reference with inline documentation |

## Startup Flow

`start-mailserver.sh` registers functions conditionally based on ENV, then runs: variables, then checks, then setup, then daemons (managed by supervisord, see `target/supervisor/`). Registration order matters and is documented inline. On container restart (`/CONTAINER_START` exists) most setup is skipped, so setup code only runs on a fresh container.

## Commands

All tooling runs in Docker. Requires `git submodule update --init --recursive` and `jq`, `parallel`, `file` on the host. macOS is unsupported.

```sh
make lint                                     # eclint, hadolint, bashcheck, shellcheck
make build                                    # builds mailserver-testing:ci
make clean generate-accounts test/<name>      # single test file, without .bats; comma-separate for multiple
make clean generate-accounts tests/parallel/set1
make clean tests                              # full suite (slow)
```

Tests run against the built image. After changing anything under `target/` or the `Dockerfile`, run `make build` before testing, or the tests exercise stale code.

## Bash Conventions

ShellCheck runs with `--enable=all` (see `test/linting/lint.sh`), and the code base is deliberately uniform. Match it:

- shebang `#!/bin/bash`, 2-space indent, LF; follow `.editorconfig`
- always brace and quote expansions (`"${VAR}"`), use `[[ ]]`, never `[ ]`
- upper-case variable names, including `local` ones
- declare functions as `function _name() { ... }`; a `__` prefix marks file-internal helpers
- log with `_log '<trace|debug|info|warn|error>' '<message>'`, never bare `echo`
- fail startup with the `_dms_panic__*` functions from `helpers/error.sh`
- reuse helpers before writing new ones, e.g. `_add_to_or_update_postfix_main`, `_replace_by_env_in_file`, `_env_var_expect_zero_or_one`
- use `sedfile -i` (or `sedfile --strict -i`) when an edit is expected to change a file; it fails if the file was left untouched

## Adding or Changing an Environment Variable

A complete change touches all of these:

1. default value in `target/scripts/startup/variables-stack.sh` (`VARS[NAME]="${NAME:=default}"`), plus validation if needed
2. documented entry in `mailserver.env`
3. entry in `docs/content/config/environment.md`
4. `CHANGELOG.md` under `Unreleased`
5. a test covering the new behavior

When renaming or removing a variable, add an error to `__environment_variables_backwards_compatibility` and list it under `Breaking` in the changelog.

## Tests

- put new tests in `test/tests/parallel/setN/`; use `serial/` only if the test cannot run concurrently
- start from `test/tests/parallel/set2/template.bats`
- `CONTAINER_NAME` must be unique and prefixed with `dms-test_`; set `BATS_TEST_NAME_PREFIX`
- wait for readiness with helpers such as `_wait_for_service` or `_repeat_until_success_or_timeout`, never with `sleep`
- per-container config copies go to `TEST_TMP_CONFIG`; do not modify `test/config/` from within a test

## Docs

- use MkDocs Material admonitions (`!!! note`) and reference-style links collected at the bottom of each page, as existing pages do
- preview locally: `docker run --rm -it -p 8000:8000 -v "./docs:/docs" docker.io/squidfunk/mkdocs-material:9.7`

## Commits and PRs

- commit subjects use Conventional Commit prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `tests:`, `chore:`, `ci:`, `breaking:`
- add user-facing changes to `CHANGELOG.md` under `Unreleased` in the matching section (`Breaking`, `Added`, `Fixed`, `Documentation`, `CI`), with a link to the PR
- fill in `.github/pull_request_template.md`
