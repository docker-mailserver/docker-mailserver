load 'test_helper/common'

function setup() {
  run_setup_file_if_necessary
}

function teardown() {
  run_teardown_file_if_necessary
}

function setup_file() {
  local PRIVATE_CONFIG CONTAINER_NAME VOLUME_CONFIG VOLUME_TEST_FILES VOLUME_LETSENCRYPT
  VOLUME_TEST_FILES="$(pwd)/test/test-files:/tmp/docker-mailserver-test:ro"


  CONTAINER_NAME='mail_lets_domain'
  PRIVATE_CONFIG="$(duplicate_config_for_container . "${CONTAINER_NAME}")"
  VOLUME_CONFIG="${PRIVATE_CONFIG}:/tmp/docker-mailserver"
  VOLUME_LETSENCRYPT="${PRIVATE_CONFIG}/letsencrypt/my-domain.com:/etc/letsencrypt/live/my-domain.com"

  docker run -d --name "${CONTAINER_NAME}" \
    -v "${VOLUME_CONFIG}" \
    -v "${VOLUME_TEST_FILES}" \
    -v "${VOLUME_LETSENCRYPT}" \
    -e DMS_DEBUG=0 \
    -e SSL_TYPE='letsencrypt' \
    -h 'mail.my-domain.com' \
    -t "${NAME}"
  wait_for_finished_setup_in_container "${CONTAINER_NAME}"


  CONTAINER_NAME='mail_lets_hostname'
  PRIVATE_CONFIG="$(duplicate_config_for_container . "${CONTAINER_NAME}")"
  VOLUME_CONFIG="${PRIVATE_CONFIG}:/tmp/docker-mailserver"
  VOLUME_LETSENCRYPT="${PRIVATE_CONFIG}/letsencrypt/mail.my-domain.com:/etc/letsencrypt/live/mail.my-domain.com"

  docker run -d --name "${CONTAINER_NAME}" \
    -v "${VOLUME_CONFIG}" \
    -v "${VOLUME_TEST_FILES}" \
    -v "${VOLUME_LETSENCRYPT}" \
    -e DMS_DEBUG=0 \
    -e SSL_TYPE='letsencrypt' \
    -h 'mail.my-domain.com' \
    -t "${NAME}"
  wait_for_finished_setup_in_container "${CONTAINER_NAME}"


  CONTAINER_NAME='mail_lets_acme_json'
  PRIVATE_CONFIG="$(duplicate_config_for_container . "${CONTAINER_NAME}")"
  VOLUME_CONFIG="${PRIVATE_CONFIG}:/tmp/docker-mailserver"
  VOLUME_LETSENCRYPT="${PRIVATE_CONFIG}/acme.json:/etc/letsencrypt/acme.json:ro"
  # Copy will mounted as volume and overwritten with another `acme.json` during testing:
  cp "$(private_config_path "${CONTAINER_NAME}")/letsencrypt/acme.json" "$(private_config_path "${CONTAINER_NAME}")/acme.json"

  docker run -d --name "${CONTAINER_NAME}" \
    -v "${VOLUME_CONFIG}" \
    -v "${VOLUME_TEST_FILES}" \
    -v "${VOLUME_LETSENCRYPT}" \
    -e DMS_DEBUG=1 \
    -e SSL_TYPE='letsencrypt' \
    -e SSL_DOMAIN='*.example.com' \
    -h 'mail.my-domain.com' \
    -t "${NAME}"
  wait_for_finished_setup_in_container "${CONTAINER_NAME}"
}

function teardown_file() {
  docker rm -f mail_lets_domain
  docker rm -f mail_lets_hostname
  docker rm -f mail_lets_acme_json
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
  cp "$(private_config_path mail_lets_acme_json)/letsencrypt/acme-changed.json" "$(private_config_path mail_lets_acme_json)/acme.json"
  sleep 11
  run docker exec mail_lets_acme_json /bin/bash -c "supervisorctl tail changedetector"
  assert_output --partial "postfix: stopped"
  assert_output --partial "postfix: started"
  assert_output --partial "Change detected"

  run docker exec mail_lets_acme_json /bin/bash -c "cat /etc/letsencrypt/live/example.com/key.pem"
  assert_output "$(cat "$(private_config_path mail_lets_acme_json)/letsencrypt/changed/key.pem")"
  assert_success

  run docker exec mail_lets_acme_json /bin/bash -c "cat /etc/letsencrypt/live/example.com/fullchain.pem"
  assert_output "$(cat "$(private_config_path mail_lets_acme_json)/letsencrypt/changed/fullchain.pem")"
  assert_success
}


 # this test is only there to reliably mark the end for the teardown_file
@test "last" {
  skip 'Finished testing of letsencrypt SSL'
}
