load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

# Docs:
# https://docker-mailserver.github.io/docker-mailserver/edge/config/advanced/mail-sieve/

BATS_TEST_NAME_PREFIX='[Dovecot] (Sieve support) '
CONTAINER_NAME='dms-test_dovecot-sieve'

function setup_file() {
  _init_with_defaults

  # Move sieve configs into main `/tmp/docker-mailserver` config location:
  mv "${TEST_TMP_CONFIG}/dovecot-sieve/"* "${TEST_TMP_CONFIG}/"

  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env ENABLE_MANAGESIEVE=1
    # Required for mail delivery via nc:
    --env PERMIT_DOCKER=container
    # Mount into home dir for user1 to treat as a user-sieve:
    # NOTE: Cannot use ':ro', 'start-mailserver.sh' attempts to 'chown -R' /var/mail:
    --volume "${TEST_TMP_CONFIG}/dovecot.sieve:/var/mail/localhost.localdomain/user1/home/.dovecot.sieve"
  )
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  _wait_for_smtp_port_in_container

  # Single mail sent from 'spam@spam.com' that is handled by User (relocate) and Global (copy) sieves for user1:
  _send_email 'email-templates/sieve-spam-folder'
  # Mail for user2 triggers the sieve-pipe:
  _send_email 'email-templates/sieve-pipe'

  _wait_for_empty_mail_queue_in_container
}

function teardown_file() { _default_teardown ; }

# dovecot-sieve/dovecot.sieve
@test "User Sieve - should store mail from 'spam@spam.com' into recipient (user1) mailbox 'INBOX.spam'" {
  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/.INBOX.spam/new 1
}

# dovecot-sieve/before.dovecot.sieve
@test "Global Sieve - should have copied mail from 'spam@spam.com' to recipient (user1) inbox" {
  _run_in_container grep -R 'Spambot <spam@spam.com>' /var/mail/localhost.localdomain/user1/new/
  assert_success
}

# dovecot-sieve/sieve-pipe + dovecot-sieve/user2@otherdomain.tld.dovecot.sieve
@test "Sieve Pipe - should pipe mail received for user2 into '/tmp/pipe-test.out'" {
  _run_in_container_bash '[[ -f /tmp/pipe-test.out ]]'
  assert_success
}

# Only test coverage for feature is to check that the service is listening on the expected port:
# https://doc.dovecot.org/admin_manual/pigeonhole_managesieve_server/
@test "ENV 'ENABLE_MANAGESIEVE' - should have enabled service on port 4190" {
  _run_in_container nc -z 0.0.0.0 4190
  assert_success
}
