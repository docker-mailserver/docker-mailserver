load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking process: fetchmail (fetchmail server enabled)" {
  run docker exec mail_fetchmail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  assert_success
}

@test "checking fetchmail: gerneral options in fetchmailrc are loaded" {
  run docker exec mail_fetchmail grep 'set syslog' /etc/fetchmailrc
  assert_success
}

@test "checking fetchmail: fetchmail.cf is loaded" {
  run docker exec mail_fetchmail grep 'pop3.example.com' /etc/fetchmailrc
  assert_success
}

@test "checking restart of process: fetchmail" {
  run docker exec mail_fetchmail /bin/bash -c "pkill fetchmail && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  assert_success
}

