load 'test_helper/common'

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_getmail \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_GETMAIL=1 \
    --cap-add=NET_ADMIN \
    -h mail.my-domain.com -t "${NAME}"

  wait_for_finished_setup_in_container mail_getmail
}

function teardown_file() {
  docker rm -f mail_getmail
}
