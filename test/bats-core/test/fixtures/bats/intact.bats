@test "dash-e on beginning of line" {
  run cat - <<INPUT
-e
INPUT
  test "$output" = "-e"
}
