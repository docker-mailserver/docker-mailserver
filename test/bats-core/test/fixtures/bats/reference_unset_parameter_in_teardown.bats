teardown() {
  set -u
  echo "$unset_parameter"
}

@test "referencing unset parameter fails in teardown" {
  :
}
