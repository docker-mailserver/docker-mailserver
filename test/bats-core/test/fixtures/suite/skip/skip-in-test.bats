#!/usr/bin/env bats

@test "skip in test" {
	skip "This is not working (https://github.com/clearcontainers/runtime/issues/1042)"
}
