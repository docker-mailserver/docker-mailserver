setup_file() {
    echo "$BATS_TEST_FILENAME" >> "$LOG"
}

@test "test" {
    true
}