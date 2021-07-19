teardown_file() {
    echo "$BATS_TEST_FILENAME" >> "$LOG"
}

@test "long running test" {
    sleep 10
    echo "test finished successfully" >> "$LOG"
}