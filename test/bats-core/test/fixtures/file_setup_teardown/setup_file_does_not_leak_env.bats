setup_file() {
    export SETUP_FILE_VAR="$BATS_TEST_FILENAME"
}

@test "test" {
    true
}