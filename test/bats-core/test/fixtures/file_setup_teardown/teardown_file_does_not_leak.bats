teardown_file() {
    export POTENTIALLY_LEAKING_VARIABLE="$BATS_TEST_FILENAME"
}

@test "test" {
    true
}