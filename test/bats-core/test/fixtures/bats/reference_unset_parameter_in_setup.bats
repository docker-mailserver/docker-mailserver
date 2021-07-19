setup() {
  set -u
  echo "$unset_parameter"
}

teardown() {
  echo "should not capture the next line"
  [ 1 -eq 2 ]
}

@test "referencing unset parameter fails in setup" {
  :
}
