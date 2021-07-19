#!/usr/bin/env bats

@test "skip in teardown" {
  true
}

teardown() {
	skip "This is not working (https://github.com/clearcontainers/runtime/issues/1042)"
}
