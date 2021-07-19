#!/usr/bin/env bats

setup () {
	skip "This is not working (https://github.com/kata-containers/runtime/issues/175)"
}

@test "skip in setup and teardown" {
  true
}

@test "skip in setup, test and teardown" {
  skip
}

teardown() {
	skip "This is not working (https://github.com/clearcontainers/runtime/issues/1042)"
}
