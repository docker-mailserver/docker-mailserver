setup_file() {
    export FILE_MARKER=$(mktemp)
    if [[ -n "${DISABLE_IN_SETUP_FILE_FUNCTION}" ]]; then
        export BATS_NO_PARALLELIZE_WITHIN_FILE=true
        echo "setup_file() sets BATS_NO_PARALLELIZE_WITHIN_FILE=true" >&2
    fi
}

if [[ -n "${DISABLE_OUTSIDE_ALL_FUNCTIONS}" ]]; then
    export BATS_NO_PARALLELIZE_WITHIN_FILE=true
    echo "File sets BATS_NO_PARALLELIZE_WITHIN_FILE=true" >&2
fi

teardown_file() {
    rm "$FILE_MARKER"
}

setup() {
    if [[ -n "${DISABLE_IN_SETUP_FUNCTION}" ]]; then
        export BATS_NO_PARALLELIZE_WITHIN_FILE=true
        echo "setup() sets BATS_NO_PARALLELIZE_WITHIN_FILE=true" >&3
    fi
    echo "start $BATS_TEST_NAME" >> "$FILE_MARKER"
}

teardown() {
    echo "end $BATS_TEST_NAME" >> "$FILE_MARKER"
}

@test "test 1" {
    if [[ -n "${DISABLE_IN_TEST_FUNCTION}" ]]; then
        export BATS_NO_PARALLELIZE_WITHIN_FILE=true
        echo "Test function sets BATS_NO_PARALLELIZE_WITHIN_FILE=true" >&3
    fi
    # stretch the time this test runs to prevent accidental serialization by the scheduler
    # if both tests could run in parallel, this will increase the likelyhood of detecting it
    # by delaying this test's teardown past the other's
    sleep 3
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