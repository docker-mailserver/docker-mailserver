# see issue #89
loop_func() {
  local search="none one two tree"
  local d

  for d in $search ; do
    echo $d
  done
}

@test "loop_func" {
  run loop_func
  [[ "${lines[3]}" == 'tree' ]]
  run loop_func
  [[ "${lines[2]}" == 'two' ]]
}
