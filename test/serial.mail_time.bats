load 'test_helper/common'

setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_time \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e TZ='Asia/Jakarta' \
    -e LOG_LEVEL=debug \
    -h mail.my-domain.com -t "${NAME}"

  wait_for_smtp_port_in_container mail_time
}

teardown_file() {
  docker rm -f mail_time
}

@test "checking time: setting the time with TZ works correctly" {
  run docker exec mail_time cat /etc/timezone
  assert_success
  assert_output 'Asia/Jakarta'

  run docker exec mail_time date '+%Z'
  assert_success
  assert_output 'WIB'
}
