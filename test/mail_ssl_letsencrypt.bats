load 'test_helper/common'

function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

function setup_file() {
  local PRIVATE_CONFIG

  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_lets_domain)"
  docker run -d --name mail_lets_domain \
  -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
  -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
  -v "${PRIVATE_CONFIG}/letsencrypt/my-domain.com":/etc/letsencrypt/live/my-domain.com \
  -e DMS_DEBUG=0 \
  -e SSL_TYPE=letsencrypt \
  -h mail.my-domain.com -t "${NAME}"
  wait_for_finished_setup_in_container mail_lets_domain

  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_lets_hostname)"
  docker run -d --name mail_lets_hostname \
  -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
  -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
  -v "${PRIVATE_CONFIG}/letsencrypt/mail.my-domain.com":/etc/letsencrypt/live/mail.my-domain.com \
  -e DMS_DEBUG=0 \
  -e SSL_TYPE=letsencrypt \
  -h mail.my-domain.com -t "${NAME}"
  wait_for_finished_setup_in_container mail_lets_hostname

  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_lets_acme_json)"
  cp "$(private_config_path mail_lets_acme_json)/letsencrypt/mail.my-domain.com/acme.json" "$(private_config_path mail_lets_acme_json)/acme.json"
  docker run -d --name mail_lets_acme_json \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "${PRIVATE_CONFIG}/acme.json":/etc/letsencrypt/acme.json:ro \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e DMS_DEBUG=1 \
    -e SSL_TYPE=letsencrypt \
    -e "SSL_DOMAIN=*.example.com" \
    -h mail.my-domain.com -t "${NAME}"
  wait_for_finished_setup_in_container mail_lets_acme_json

  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_lets_acme_json_example_wildcard)"
  cp "$(private_config_path mail_lets_acme_json_example_wildcard)/letsencrypt/wildcard.example.com/acme.json" "$(private_config_path mail_lets_acme_json_example_wildcard)/acme.json"
  docker run -d --name mail_lets_acme_json_example_wildcard \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "${PRIVATE_CONFIG}/acme.json":/etc/letsencrypt/acme.json:ro \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e DMS_DEBUG=1 \
    -e SSL_TYPE=letsencrypt \
    -h example.com -t "${NAME}"
  wait_for_finished_setup_in_container mail_lets_acme_json_example_wildcard
}

function teardown_file() {
  docker rm -f mail_lets_domain
  docker rm -f mail_lets_hostname
  docker rm -f mail_lets_acme_json
  docker rm -f mail_lets_acme_json_example_wildcard
}

# this test must come first to reliably identify when to run setup_file
@test "first" {
  skip 'Starting testing of letsencrypt SSL'
}

@test "checking ssl: letsencrypt configuration is correct" {
  #test domain has certificate files
  run docker exec mail_lets_domain /bin/sh -c 'postconf | grep "smtpd_tls_chain_files = /etc/letsencrypt/live/my-domain.com/key.pem /etc/letsencrypt/live/my-domain.com/fullchain.pem" | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_lets_domain /bin/sh -c 'doveconf | grep "ssl_cert = </etc/letsencrypt/live/my-domain.com/fullchain.pem" | wc -l'
  assert_success
  assert_output 1
  run docker exec mail_lets_domain /bin/sh -c 'doveconf -P | grep "ssl_key = </etc/letsencrypt/live/my-domain.com/key.pem" | wc -l'
  assert_success
  assert_output 1
  #test hostname has certificate files
  run docker exec mail_lets_hostname /bin/sh -c 'postconf | grep "smtpd_tls_chain_files = /etc/letsencrypt/live/mail.my-domain.com/privkey.pem /etc/letsencrypt/live/mail.my-domain.com/fullchain.pem" | wc -l'
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

#
# acme.json updates
#

@test "checking changedetector: server is ready" {
  run docker exec mail_lets_acme_json /bin/bash -c "ps aux | grep '/bin/bash /usr/local/bin/check-for-changes.sh'"
  assert_success
}

@test "can extract certs from acme.json" {
  run docker exec mail_lets_acme_json /bin/bash -c "cat /etc/letsencrypt/live/mail.my-domain.com/key.pem"
  assert_output "$(cat "$(private_config_path mail_lets_acme_json)/letsencrypt/mail.my-domain.com/privkey.pem")"
  assert_success

  run docker exec mail_lets_acme_json /bin/bash -c "cat /etc/letsencrypt/live/mail.my-domain.com/fullchain.pem"
  assert_output "$(cat "$(private_config_path mail_lets_acme_json)/letsencrypt/mail.my-domain.com/fullchain.pem")"
  assert_success
}

@test "can detect changes" {
  cp "$(private_config_path mail_lets_acme_json)/letsencrypt/mail.my-domain.com/changed/acme.json" "$(private_config_path mail_lets_acme_json)/acme.json"
  sleep 15
  run docker exec mail_lets_acme_json /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "Change detected"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"

  run docker exec mail_lets_acme_json /bin/bash -c "cat /etc/letsencrypt/live/mail.my-domain.com/fullchain.pem"
  assert_output "$(cat "$(private_config_path mail_lets_acme_json)/letsencrypt/mail.my-domain.com/changed/fullchain.pem")"
  assert_success
  run docker exec mail_lets_acme_json /bin/bash -c "cat /etc/letsencrypt/live/mail.my-domain.com/key.pem"
  assert_output "$(cat "$(private_config_path mail_lets_acme_json)/letsencrypt/mail.my-domain.com/changed/key.pem")"
  assert_success
}

@test "can detect changes (wildcard example.com)" {
  cp "$(private_config_path mail_lets_acme_json_example_wildcard)/letsencrypt/wildcard.example.com/changed/acme.json" "$(private_config_path mail_lets_acme_json_example_wildcard)/acme.json"
  sleep 15
  run docker exec mail_lets_acme_json_example_wildcard /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "Change detected"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"

  run docker exec mail_lets_acme_json_example_wildcard /bin/bash -c "cat /etc/letsencrypt/live/example.com/fullchain.pem"
  assert_output "$(cat "$(private_config_path mail_lets_acme_json_example_wildcard)/letsencrypt/wildcard.example.com/changed/fullchain.pem")"
  assert_success
}

# this test is only there to reliably mark the end for the teardown_file
@test "last" {
  skip 'Finished testing of letsencrypt SSL'
}
