teardown() {
  source "nonexistent file"
}

@test "sourcing nonexistent file fails in teardown" {
  :
}
