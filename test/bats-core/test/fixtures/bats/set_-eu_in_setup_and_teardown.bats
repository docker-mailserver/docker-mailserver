setup() {
    set -eu
}

teardown() {
    set -eu
}

@test "skipped test" {
    skip
}

@test "skipped test with reason" {
    skip "reason"
}

@test "passing test" {
    run true
}

@test "failing test" {
    false
}