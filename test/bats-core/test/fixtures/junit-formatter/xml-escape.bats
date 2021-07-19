@test "Successful test with escape characters: \"'<>&[0m (0x1b)" {
  true
}

@test "Failed test with escape characters: \"'<>&[0m (0x1b)" {
  echo "<>'&[0m" && false
}

@test "Skipped test with escape characters: \"'<>&[0m (0x1b)" {
  skip "\"'<>&[0m"
}