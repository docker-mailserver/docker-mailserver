@test "referencing unset parameter fails" {
  set -u
  echo "$unset_parameter"
}
