@test "checking sasl: doveadm auth test works with good password" {
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld mypassword | grep 'auth succeeded'"

  if [ -n "$SASL_PASSWD" ]; then
    [ "$status" -eq 0 ]
  else
    [ "$status" -eq 1 ]
  fi
}

@test "checking sasl: doveadm auth test fails with bad password" {
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld BADPASSWORD | grep 'auth failed'"

  if [ -n "$SASL_PASSWD" ]; then
    [ "$status" -eq 0 ]
  else
    [ "$status" -eq 1 ]
  fi
}

@test "checking sasl: sasl_passwd.db exists" {
  run docker exec mail [ -f /etc/postfix/sasl_passwd.db ]

  if [ -n "$SASL_PASSWD" ]; then
    [ "$status" -eq 0 ]
  else
    [ "$status" -eq 1 ]
  fi
}
