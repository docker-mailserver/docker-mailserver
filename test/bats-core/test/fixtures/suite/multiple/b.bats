@test "more truth" {
  true
}

@test "quasi-truth" {
  [ -z "$FLUNK" ]
}
