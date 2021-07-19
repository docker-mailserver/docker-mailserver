setup() {
    echo "start $BATS_TEST_NAME" >> "$FILE_MARKER"
}

teardown() {
    echo "end $BATS_TEST_NAME" >> "$FILE_MARKER"
}

@test "test 1" {
    # stretch the time this test runs to prevent accidental serialization by the scheduler
    # if both tests could run in parallel, this will increase the likelihood of detecting it
    # by delaying this test's teardown past the other's
    sleep 3
}
