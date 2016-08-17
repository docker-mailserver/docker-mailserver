@test "checking process: dovecot imaplogin (disabled using SMTP_ONLY)" {
  if [ "$SMTP_ONLY" != 1 ]; then
    skip
  fi
  run docker exec mail_smtponly /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/dovecot'"
  [ "$status" -eq 1 ]
}