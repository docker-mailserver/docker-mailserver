load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking ssl: manual configuration is correct" {
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/cert" /etc/postfix/main.cf | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/cert" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/key" /etc/postfix/main.cf | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_manual_ssl /bin/sh -c 'grep -ir "/etc/postfix/ssl/key" /etc/dovecot/conf.d/10-ssl.conf | wc -l'
  assert_success
  assert_output 1
}

@test "checking ssl: manual configuration copied files correctly " {
  run docker exec mail_manual_ssl /bin/sh -c 'cmp -s /etc/postfix/ssl/cert /tmp/docker-mailserver/letsencrypt/mail.my-domain.com/fullchain.pem'
  assert_success
  run docker exec mail_manual_ssl /bin/sh -c 'cmp -s /etc/postfix/ssl/key /tmp/docker-mailserver/letsencrypt/mail.my-domain.com/privkey.pem'
  assert_success
}

@test "checking ssl: manual cert works correctly" {
  run docker exec mail_manual_ssl /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

