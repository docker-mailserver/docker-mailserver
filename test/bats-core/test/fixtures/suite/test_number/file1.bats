#!/usr/bin/env bats

@test "first test in file 1" {
    echo "BATS_TEST_NUMBER=$BATS_TEST_NUMBER"
    [[ "$BATS_TEST_NUMBER" == 1 ]]
    echo "BATS_SUITE_TEST_NUMBER=$BATS_SUITE_TEST_NUMBER"
    [[ "$BATS_SUITE_TEST_NUMBER" == 1 ]]
}

@test "second test in file 1" {
    [[ "$BATS_TEST_NUMBER" == 2 ]]
    [[ "$BATS_SUITE_TEST_NUMBER" == 2 ]]
}

@test "BATS_TEST_NAMES is per file" {
    echo "${#BATS_TEST_NAMES[@]}"
    [[ "${#BATS_TEST_NAMES[@]}" == 3 ]]
}
