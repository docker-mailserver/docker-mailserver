#!/usr/bin/env bats

@test "test 1" {
    # Don't print anything
    run bash -c "$BATS_TEST_DIRNAME/cmd_using_stdin.bash"
    [ "$status" -eq 1 ]
    [ "$output" = "Not found" ]
}

@test "test 2 with	TAB in name" {
    run bash -c "echo EXIT | $BATS_TEST_DIRNAME/cmd_using_stdin.bash"
    [ "$status" -eq 0 ]
    echo "$output"
    [ "$output" = "Found" ]
}

@test "test 3" {
    run bash -c "echo EXIT | $BATS_TEST_DIRNAME/cmd_using_stdin.bash"
    [ "$status" -eq 0 ]
    [ "$output" = "Found" ]
}
