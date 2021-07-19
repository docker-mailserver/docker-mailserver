#!/usr/bin/env bats

@test "a skipped test" {
  skip
}

@test "a skipped test with a reason" {
  skip "a reason"
}