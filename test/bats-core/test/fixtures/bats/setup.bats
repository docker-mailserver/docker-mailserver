LOG="$BATS_TEST_SUITE_TMPDIR/setup.log"

setup() {
  echo "$BATS_TEST_NAME" >> "$LOG"
}

@test "one" {
  [ "$(tail -n 1 "$LOG")" = "test_one" ]
}

@test "two" {
  [ "$(tail -n 1 "$LOG")" = "test_two" ]
}

@test "three" {
  [ "$(tail -n 1 "$LOG")" = "test_three" ]
}
