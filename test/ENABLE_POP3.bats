@test "checking pop: server is ready" {
  run docker exec mail /bin/bash -c "nc -w 1 0.0.0.0 110 | grep '+OK'"

  if [ $ENABLE_POP -eq 1 ]; then
    [ "$status" -eq 0 ]
  else
    [ "$status" -eq 1 ]
  fi
}

@test "checking pop: authentication works" {
  run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/pop3-auth.txt"

  if [ $ENABLE_POP -eq 1 ]; then
    [ "$status" -eq 0 ]
  else
    [ "$status" -eq 1 ]
  fi
}
