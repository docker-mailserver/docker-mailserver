@test "success writing to stdout" {
  echo "success stdout 1"
  echo "success stdout 2"
}

@test "success writing to stderr" {
  echo "success stderr" >&2
}

@test "failure writing to stdout" {
  echo "failure stdout 1"
  echo "failure stdout 2"
  false
}

@test "failure writing to stderr" {
  echo "failure stderr" >&2
  false
}
