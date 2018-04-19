load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking relay hosts: default mapping is added from env vars" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domainone.tld\s\+\[default.relay.com\]:2525" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: custom mapping is added from file" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domaintwo.tld\s\+\[other.relay.com\]:587" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: ignored domain is not added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/relayhost_map | grep -e "^@domainthree.tld\s\+\[any.relay.com\]:25" | wc -l | grep 0'
  assert_success
}

@test "checking relay hosts: auth entry is added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/sasl_passwd | grep -e "^@domaintwo.tld\s\+smtp_user_2:smtp_password_2" | wc -l | grep 1'
  assert_success
}

@test "checking relay hosts: default auth entry is added" {
  run docker exec mail_with_relays /bin/sh -c 'cat /etc/postfix/sasl_passwd | grep -e "^\[default.relay.com\]:2525\s\+smtp_user:smtp_password" | wc -l | grep 1'
  assert_success
}

