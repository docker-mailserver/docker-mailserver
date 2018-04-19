load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking opendkim: /etc/opendkim/KeyTable dummy file generated without keys provided" {
  run docker exec mail_smtponly_without_config /bin/bash -c "cat /etc/opendkim/KeyTable"
  assert_success
}

