#!/usr/bin/env bats

teardown() {
	skip "This is not working (https://github.com/clearcontainers/runtime/issues/1042)"
}

@test "skip in test and teardown" {
	skip "This is not working (https://github.com/clearcontainers/runtime/issues/1042)"
}
