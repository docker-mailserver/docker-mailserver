load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking postfix: remove privacy details of the sender" {
  run docker exec mail_privacy /bin/sh -c "ls /var/mail/localhost.localdomain/user1/new | wc -l"
  assert_success
  assert_output 1
  run docker exec mail_privacy /bin/sh -c "grep -rE "^User-Agent:" /var/mail/localhost.localdomain/user1/new | wc -l"
  assert_success
  assert_output 0
}

