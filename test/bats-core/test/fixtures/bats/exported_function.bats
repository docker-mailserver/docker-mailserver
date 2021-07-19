if exported_function; then
  a='exported_function'
fi

@test "failing test" {
  echo "a='$a'"
  false
}
