setup_file() {
    load 'helper'
    echo "start $BATS_TEST_FILENAME" >> "${FILE_MARKER?}"
    single-use-barrier setup-file ${PARALLELITY?} 10
}

teardown_file() {
    echo "stop $BATS_TEST_FILENAME" >> "$FILE_MARKER"
}

@test "nothing" {
    true
}