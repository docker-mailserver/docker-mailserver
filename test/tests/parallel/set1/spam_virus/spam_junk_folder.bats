load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

# Tests originally contributed in PR: https://github.com/docker-mailserver/docker-mailserver/pull/1485
# That introduced both ENV: SPAMASSASSIN_SPAM_TO_INBOX and MOVE_SPAM_TO_JUNK

BATS_TEST_NAME_PREFIX='[Spam - Amavis] ENV SPAMASSASSIN_SPAM_TO_INBOX '
CONTAINER1_NAME='dms-test_spam-amavis_bounced'
CONTAINER2_NAME='dms-test_spam-amavis_env-move-spam-to-junk-0'
CONTAINER3_NAME='dms-test_spam-amavis_env-move-spam-to-junk-1'
CONTAINER4_NAME='dms-test_spam-amavis_env-mark-spam-as-read-1'

function teardown() { _default_teardown ; }

@test "(disabled) spam message should be bounced (rejected)" {
  export CONTAINER_NAME=${CONTAINER1_NAME}

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_SPAMASSASSIN=1
    --env SPAMASSASSIN_SPAM_TO_INBOX=0
    --env PERMIT_DOCKER=container
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _should_send_spam_message
  _should_be_received_by_amavis 'Blocked SPAM {NoBounceInbound,Quarantined}'
}

@test "(enabled + MOVE_SPAM_TO_JUNK=0) should deliver spam message into INBOX" {
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

  _should_send_spam_message
  _should_be_received_by_amavis 'Passed SPAM {RelayedTaggedInbound,Quarantined}'

  # Should move delivered spam to INBOX
  _should_receive_spam_at '/var/mail/localhost.localdomain/user1/new/'
}

@test "(enabled + MOVE_SPAM_TO_JUNK=1) should deliver spam message into Junk folder" {
  export CONTAINER_NAME=${CONTAINER3_NAME}

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

  _should_send_spam_message
  _should_be_received_by_amavis 'Passed SPAM {RelayedTaggedInbound,Quarantined}'

  # Should move delivered spam to Junk folder
  _should_receive_spam_at '/var/mail/localhost.localdomain/user1/.Junk/new/'
}

# NOTE: Same as test for `CONTAINER3_NAME`, only differing by ENV `MARK_SPAM_AS_READ=1` + `_should_receive_spam_at` location
@test "(enabled + MARK_SPAM_AS_READ=1) should mark spam message as read" {
  export CONTAINER_NAME=${CONTAINER4_NAME}

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_SPAMASSASSIN=1
    --env SA_SPAM_SUBJECT="SPAM: "
    --env SPAMASSASSIN_SPAM_TO_INBOX=1
    --env MARK_SPAM_AS_READ=1
    --env PERMIT_DOCKER=container
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _should_send_spam_message
  _should_be_received_by_amavis 'Passed SPAM {RelayedTaggedInbound,Quarantined}'

  # Should move delivered spam to Junk folder as read (`cur` instead of `new`)
  _should_receive_spam_at '/var/mail/localhost.localdomain/user1/.Junk/cur/'
}

function _should_send_spam_message() {
  _wait_for_smtp_port_in_container
  _wait_for_tcp_port_in_container 10024 # port 10024 is for Amavis
  _send_email 'email-templates/amavis-spam'
}

function _should_be_received_by_amavis() {
  local MATCH_CONTENT=${1}

  # message will be added to a queue with varying delay until amavis receives it
  _run_in_container_bash "timeout 60 tail -F /var/log/mail/mail.log | grep --max-count 1 '${MATCH_CONTENT}'"
  assert_success
}

function _should_receive_spam_at() {
  local MAIL_DIR=${1}

  # spam moved into MAIL_DIR
  _repeat_in_container_until_success_or_timeout 20 "${CONTAINER_NAME}" grep -R 'Subject: SPAM: ' "${MAIL_DIR}"
  assert_success
}
