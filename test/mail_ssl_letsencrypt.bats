load 'test_helper/common'

function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

function setup_file() {
  docker run -d --name mail_lets_domain \
  -v "`pwd`/test/config":/tmp/docker-mailserver \
  -v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
  -v "`pwd`/test/config/letsencrypt/my-domain.com":/etc/letsencrypt/live/my-domain.com \
  -e DMS_DEBUG=0 \
  -e SSL_TYPE=letsencrypt \
  -h mail.my-domain.com -t ${NAME}
  wait_for_finished_setup_in_container mail_lets_domain

  docker run -d --name mail_lets_hostname \
  -v "`pwd`/test/config":/tmp/docker-mailserver \
  -v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
  -v "`pwd`/test/config/letsencrypt/mail.my-domain.com":/etc/letsencrypt/live/mail.my-domain.com \
  -e DMS_DEBUG=0 \
  -e SSL_TYPE=letsencrypt \
  -h mail.my-domain.com -t ${NAME}
  wait_for_finished_setup_in_container mail_lets_hostname
}

function teardown_file() {
  docker rm -f mail_lets_domain
  docker rm -f mail_lets_hostname
}

# this test must come first to reliably identify when to run setup_file
@test "first" {
  skip 'Starting testing of letsencrypt SSL'
}

@test "checking ssl: letsencrypt configuration is correct" {
  #test domain has certificate files
  run docker exec mail_lets_domain /bin/sh -c 'postconf | grep "smtpd_tls_cert_file = /etc/letsencrypt/live/my-domain.com/fullchain.pem" | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_lets_domain /bin/sh -c 'postconf | grep "smtpd_tls_key_file = /etc/letsencrypt/live/my-domain.com/key.pem" | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_lets_domain /bin/sh -c 'doveconf | grep "ssl_cert = </etc/letsencrypt/live/my-domain.com/fullchain.pem" | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_lets_domain /bin/sh -c 'doveconf -P | grep "ssl_key = </etc/letsencrypt/live/my-domain.com/key.pem" | wc -l'
  assert_success
  assert_output 1
  #test hostname has certificate files
  run docker exec mail_lets_hostname /bin/sh -c 'postconf | grep "smtpd_tls_cert_file = /etc/letsencrypt/live/mail.my-domain.com/fullchain.pem" | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_lets_hostname /bin/sh -c 'postconf | grep "smtpd_tls_key_file = /etc/letsencrypt/live/mail.my-domain.com/privkey.pem" | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_lets_hostname /bin/sh -c 'doveconf | grep "ssl_cert = </etc/letsencrypt/live/mail.my-domain.com/fullchain.pem" | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_lets_hostname /bin/sh -c 'doveconf -P | grep "ssl_key = </etc/letsencrypt/live/mail.my-domain.com/privkey.pem" | wc -l'
  assert_success
  assert_output 1
}

@test "checking ssl: letsencrypt cert works correctly" {
  run docker exec mail_lets_domain /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
  run docker exec mail_lets_domain /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:465 -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
  run docker exec mail_lets_hostname /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
  run docker exec mail_lets_hostname /bin/sh -c "timeout 1 openssl s_client -connect 0.0.0.0:465 -CApath /etc/ssl/certs/ | grep 'Verify return code: 10 (certificate has expired)'"
  assert_success
}

 # this test is only there to reliably mark the end for the teardown_file
@test "last" {
  skip 'Finished testing of letsencrypt SSL'
}
