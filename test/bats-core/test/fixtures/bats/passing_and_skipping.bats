@test "a passing test" {
  true
}

@test "a skipped test with no reason" {
  skip
}

@test "a skipped test with a reason" {
  skip "for a really good reason"
}
