load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    docker run -d --name mail_manual_ssl \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e SSL_TYPE=manual \
		-e SSL_CERT_PATH=/tmp/docker-mailserver/letsencrypt/mail.my-domain.com/fullchain.pem \
		-e SSL_KEY_PATH=/tmp/docker-mailserver/letsencrypt/mail.my-domain.com/privkey.pem \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t ${NAME}
    wait_for_finished_setup_in_container mail_manual_ssl
}

function teardown_file() {
    docker rm -f mail_manual_ssl
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

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

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}