load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Spam - Amavis] ENV MOVE_SPAM_TO_JUNK '
CONTAINER1_NAME='dms-test_spam-amavis_env-move-spam-to-junk-1'
CONTAINER2_NAME='dms-test_spam-amavis_env-move-spam-to-junk-0'

function teardown() { _default_teardown ; }

@test "(enabled) should deliver spam message into Junk folder" {
  export CONTAINER_NAME=${CONTAINER1_NAME}

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_SPAMASSASSIN=1
    --env SA_SPAM_SUBJECT="SPAM: "
    --env SPAMASSASSIN_SPAM_TO_INBOX=1
    --env MOVE_SPAM_TO_JUNK=1
    --env PERMIT_DOCKER=container
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Should move delivered spam to Junk folder
  _should_receive_spam_at '/var/mail/localhost.localdomain/user1/.Junk/new/'
}

@test "(disabled) should deliver spam message into INBOX" {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_SPAMASSASSIN=1
    --env SA_SPAM_SUBJECT="SPAM: "
    --env SPAMASSASSIN_SPAM_TO_INBOX=1
    --env MOVE_SPAM_TO_JUNK=0
    --env PERMIT_DOCKER=container
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Should move delivered spam to INBOX
  _should_receive_spam_at '/var/mail/localhost.localdomain/user1/new/'
}

function _should_receive_spam_at() {
  local MAIL_DIR=${1}

  _wait_for_smtp_port_in_container
  # Port 10024 (Amavis)
  _wait_for_tcp_port_in_container 10024

  # send a spam message
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  # message will be added to a queue with varying delay until amavis receives it
  _run_in_container_bash 'timeout 60 tail -F /var/log/mail/mail.log | grep --max-count 1 "Passed SPAM {RelayedTaggedInbound,Quarantined}"'
  assert_success

  # spam moved into MAIL_DIR
  _repeat_in_container_until_success_or_timeout 20 "${CONTAINER_NAME}" grep -R 'Subject: SPAM: ' "${MAIL_DIR}"
  assert_success
}
