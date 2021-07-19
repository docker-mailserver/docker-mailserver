emulate_bats_env() {
  export BATS_CWD="$PWD"
  export BATS_TEST_PATTERN="^[[:blank:]]*@test[[:blank:]]+(.*[^[:blank:]])[[:blank:]]+\{(.*)\$"
  export BATS_TEST_FILTER=
  export BATS_ROOT_PID=$$
  export BATS_EMULATED_RUN_TMPDIR="$BATS_TMPDIR/bats-run-$BATS_ROOT_PID"
  export BATS_RUN_TMPDIR="$BATS_EMULATED_RUN_TMPDIR"
  mkdir -p "$BATS_RUN_TMPDIR"
}

fixtures() {
  FIXTURE_ROOT="$BATS_TEST_DIRNAME/fixtures/$1"
  RELATIVE_FIXTURE_ROOT="${FIXTURE_ROOT#$BATS_CWD/}"
}

make_bats_test_suite_tmpdir() {
  export BATS_TEST_SUITE_TMPDIR="$BATS_RUN_TMPDIR/bats-test-tmp/$1"
  mkdir -p "$BATS_TEST_SUITE_TMPDIR"
}

filter_control_sequences() {
  "$@" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g'
}

if ! command -v tput >/dev/null; then
  tput() {
    printf '1000\n'
  }
  export -f tput
fi

emit_debug_output() {
  printf '%s\n' 'output:' "$output" >&2
}

test_helper::cleanup_tmpdir() {
  if [[ -n "$1" && -z "$BATS_TEST_SUITE_TMPDIR" ]]; then
    BATS_TEST_SUITE_TMPDIR="$BATS_RUN_TMPDIR/bats-test-tmp/$1"
  fi
  if [[ -n "$BATS_TEST_SUITE_TMPDIR" ]]; then
    rm -rf "$BATS_TEST_SUITE_TMPDIR"
  fi
  if [[ -n "$BATS_EMULATED_RUN_TMPDIR" ]]; then
    rm -rf "$BATS_EMULATED_RUN_TMPDIR"
  fi
}
