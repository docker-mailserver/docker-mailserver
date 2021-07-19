setup_file() {
    echo "$BATS_TEST_FILENAME" >> "$LOG"
}

@test "test" {
    skip "We only want to see if setup file runs"
}