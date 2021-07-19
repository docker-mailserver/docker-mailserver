@test "no final newline" {
  printf 'foo\nbar\nbaz' >&2 && return 1
}
