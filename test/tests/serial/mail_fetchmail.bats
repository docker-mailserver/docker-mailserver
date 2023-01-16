load "${REPOSITORY_ROOT}/test/test_helper/common"

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_fetchmail \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_FETCHMAIL=1 \
    --cap-add=NET_ADMIN \
    -h mail.my-domain.com -t "${NAME}"

  wait_for_finished_setup_in_container mail_fetchmail
}

function teardown_file() {
  docker rm -f mail_fetchmail
}

#
# fetchmail
#

@test "checking fetchmail: gerneral options in fetchmailrc are loaded" {
  run docker exec mail_fetchmail grep 'set syslog' /etc/fetchmailrc
  assert_success
}

@test "checking fetchmail: fetchmail.cf is loaded" {
  run docker exec mail_fetchmail grep 'pop3.example.com' /etc/fetchmailrc
  assert_success
}
