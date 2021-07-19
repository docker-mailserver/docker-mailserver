PATH="/usr/local/bin:/usr/bin:/bin"

@test "PATH is reset" {
  echo "$PATH"
  false
}
