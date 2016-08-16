@test "checking pop: ENABLE_POP3=1 => server is running" {
	if [ "$ENABLE_POP3" != 1 ]; then
		skip
	fi

    run docker exec mail /bin/bash -c "nc -w 1 0.0.0.0 110 | grep '+OK'"
    [ "$status" -eq 0 ]
  }


@test "checking pop: ENABLE_POP3=1 => authentication works" {
    if [ "$ENABLE_POP3" != 1 ]; then
		skip
    fi

    run docker exec mail /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/pop3-auth.txt"
    [ "$status" -eq 0 ]
}
