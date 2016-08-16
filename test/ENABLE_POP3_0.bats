@test "checking process: process is not running" {
  run docker exec mail /bin/bash -c "ps aux | grep 'dovecot/pop'"
  [ "$status" -eq 1 ]
}

@test "checking pop: server does not respond on port 110" {
  run docker exec mail /bin/bash -c "nc -w 1 0.0.0.0 110"
  [ "$status" -eq 1 ]
}
