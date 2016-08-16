@test "checking sasl: sasl_passwd.db should not exist" {
  run docker exec mail [ -f /etc/postfix/sasl_passwd.db ]
  [ "$status" -eq 1 ]
}
