setup() {
  source "nonexistent file"
}

teardown() {
  echo "should not capture the next line"
  [ 1 -eq 2 ]
}

@test "sourcing nonexistent file fails in setup" {
  :
}
