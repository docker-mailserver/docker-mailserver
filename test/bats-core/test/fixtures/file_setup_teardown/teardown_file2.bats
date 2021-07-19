teardown_file() {
    echo "$BATS_TEST_FILENAME" >> "$LOG"
}

@test "first" {
    true
}

@test "second" {
    true
}