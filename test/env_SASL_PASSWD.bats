####################################################################################################
#
# SASL_PASSWD provided
#
####################################################################################################

@test "checking sasl: doveadm auth test works with good password" {
  if [ -z "$SASL_PASSWD" ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld mypassword | grep 'auth succeeded'"
  [ "$status" -eq 0 ]
}

@test "checking sasl: doveadm auth test fails with bad password" {
  if [ -z "$SASL_PASSWD" ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "doveadm auth test -x service=smtp user2@otherdomain.tld BADPASSWORD | grep 'auth failed'"
  [ "$status" -eq 0 ]
}

@test "checking sasl: sasl_passwd.db exists" {
  if [ -z "$SASL_PASSWD" ]; then
    skip
  fi
  run docker exec mail [ -f /etc/postfix/sasl_passwd.db ]
  [ "$status" -eq 0 ]
}

####################################################################################################
#
# SASL_PASSWD not provided
#
####################################################################################################

@test "checking sasl: sasl_passwd.db should not exist" {
  if [ -n "$SASL_PASSWD" ]; then
    skip
  fi
  run docker exec mail [ -f /etc/postfix/sasl_passwd.db ]
  [ "$status" -eq 1 ]
}
