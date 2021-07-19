teardown_file() {
    echo "$BATS_TEST_FILENAME" >> "$LOG"
}

@test "skipped test" {
    skip 'All tests in this file are skipped! Teardown_file runs anyways'
}