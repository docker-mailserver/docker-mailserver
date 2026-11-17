load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Privacy] '
CONTAINER_NAME='dms-test_privacy'

function setup_file() {
  _init_with_defaults

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_MANAGESIEVE=1
    --env DMS_TRUSTED_NETWORKS=subnet
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
  _send_email \
    --port 587 -tls --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --data 'privacy.txt'

  _run_until_success_or_timeout 120 _exec_in_container_bash '[[ -d /var/mail/localhost.localdomain/user1/new ]]'
  assert_success

  _count_files_in_directory_in_container '/var/mail/localhost.localdomain/user1/new/' '1'

  _run_in_container_bash 'grep -rE "^User-Agent:" /var/mail/localhost.localdomain/user1/new'
  _should_output_number_of_lines 0
}

# Headers inside MIME parts can be covered by a signature (PGP/MIME protected headers),
# so only the top-level headers of the message may be filtered.
# This test covers https://github.com/docker-mailserver/docker-mailserver/issues/4830
@test "(Postfix) does not modify headers inside MIME parts" {
  _send_email \
    --port 587 -tls --auth PLAIN \
    --auth-user user1@localhost.localdomain \
    --auth-password mypassword \
    --to user2@otherdomain.tld \
    --data 'privacy-protected-headers.txt'

  _wait_for_empty_mail_queue_in_container
  _count_files_in_directory_in_container '/var/mail/otherdomain.tld/user2/new/' '1'

  # Top-level headers are filtered:
  _run_in_container_bash 'grep -rhE "^(User-Agent|X-Mailer): Outer" /var/mail/otherdomain.tld/user2/new'
  _should_output_number_of_lines 0

  # Headers inside the signed MIME part are untouched, `MIME-Version` still has its comment:
  _run_in_container_bash 'grep -rhE "^(User-Agent|X-Mailer): Inner|^MIME-Version: 1.0 \(inner\)" /var/mail/otherdomain.tld/user2/new'
  _should_output_number_of_lines 3

  # Only the top-level `Message-ID` triggers the header to be prepended (regardless of the casing):
  _run_in_container_bash 'grep -rhE "^X-MS-Reactions: disallow" /var/mail/otherdomain.tld/user2/new'
  _should_output_number_of_lines 1
}
