load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Privacy] '
CONTAINER_NAME='dms-test_privacy'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_MANAGESIEVE=1
    --env PERMIT_DOCKER=host
    --env SSL_TYPE='snakeoil'
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Port 10024 (Amavis)
  _wait_for_tcp_port_in_container 10024
  _wait_for_smtp_port_in_container
}

function teardown_file() { _default_teardown ; }

# this test covers https://github.com/docker-mailserver/docker-mailserver/issues/681
@test "(Postfix) remove privacy details of the sender" {
  _run_in_container_bash "openssl s_client -quiet -starttls smtp -connect 0.0.0.0:587 < /tmp/docker-mailserver-test/email-templates/send-privacy-email.txt"
  assert_success

  _run_until_success_or_timeout 120 _exec_in_container_bash '[[ -d /var/mail/localhost.localdomain/user1/new ]]'
  assert_success

  _count_files_in_directory_in_container '/var/mail/localhost.localdomain/user1/new/' '1'

  _run_in_container_bash 'grep -rE "^User-Agent:" /var/mail/localhost.localdomain/user1/new'
  _should_output_number_of_lines 0
}
