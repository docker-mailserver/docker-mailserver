teardown_file() {
    echo "$BATS_TEST_FILENAME" >> "$LOG"
}

@test "failing test" {
    false
}