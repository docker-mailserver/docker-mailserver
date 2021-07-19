LOG="$BATS_TEST_SUITE_TMPDIR/teardown.log"

teardown() {
  echo "$BATS_TEST_NAME" >> "$LOG"
}

@test "one" {
  true
}

@test "two" {
  false
}

@test "three" {
  true
}
