setup() {
    echo "start $BATS_TEST_NAME" >> "$FILE_MARKER"
}

teardown() {
    echo "end $BATS_TEST_NAME" >> "$FILE_MARKER"
}

@test "test 2" {
    run cat "$FILE_MARKER"
    echo "$output"

    # assuming serialized, ordered execution we will always see the first test start and end before this runs
    [[ "${lines[0]}" == "start"* ]]
    OTHER_TEST_NAME="${lines[0]:6}"
    [[ "$OTHER_TEST_NAME" != "$BATS_TEST_NAME" ]]
    [[ "${lines[1]}" == "end $OTHER_TEST_NAME" ]]
    [[ "${lines[2]}" == "start $BATS_TEST_NAME" ]]
}