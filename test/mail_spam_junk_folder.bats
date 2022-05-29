load 'test_helper/common'

# Test case
# ---------
# When SPAMASSASSIN_SPAM_TO_INBOX=1, spam messages must be delivered and eventually (MOVE_SPAM_TO_JUNK=1) moved to the Junk folder.

@test "checking amavis: spam message is delivered and moved to the Junk folder (MOVE_SPAM_TO_JUNK=1)" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_spam_moved_junk)

  docker run -d --name mail_spam_moved_junk \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_SPAMASSASSIN=1 \
    -e MOVE_SPAM_TO_JUNK=1 \
    -e PERMIT_DOCKER=container \
    -e SA_SPAM_SUBJECT="SPAM: " \
    -e SPAMASSASSIN_SPAM_TO_INBOX=1 \
    -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_spam_moved_junk; }

  wait_for_smtp_port_in_container mail_spam_moved_junk

  # send a spam message
  run docker exec mail_spam_moved_junk /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  # message will be added to a queue with varying delay until amavis receives it
  run repeat_until_success_or_timeout 60 sh -c "docker logs mail_spam_moved_junk | grep 'Passed SPAM {RelayedTaggedInbound,Quarantined}'"
  assert_success

  # spam moved to Junk folder
  run repeat_until_success_or_timeout 20 sh -c "docker exec mail_spam_moved_junk sh -c 'grep \"Subject: SPAM: \" /var/mail/localhost.localdomain/user1/.Junk/new/ -R'"
  assert_success
}

@test "checking amavis: spam message is delivered to INBOX (MOVE_SPAM_TO_JUNK=0)" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_spam_moved_new)

  docker run -d --name mail_spam_moved_new \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_SPAMASSASSIN=1 \
    -e MOVE_SPAM_TO_JUNK=0 \
    -e PERMIT_DOCKER=container \
    -e SA_SPAM_SUBJECT="SPAM: " \
    -e SPAMASSASSIN_SPAM_TO_INBOX=1 \
    -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_spam_moved_new; }

  wait_for_smtp_port_in_container mail_spam_moved_new

  # send a spam message
  run docker exec mail_spam_moved_new /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  # message will be added to a queue with varying delay until amavis receives it
  run repeat_until_success_or_timeout 60 sh -c "docker logs mail_spam_moved_new | grep 'Passed SPAM {RelayedTaggedInbound,Quarantined}'"
  assert_success

  # spam moved to INBOX
  run repeat_until_success_or_timeout 20 sh -c "docker exec mail_spam_moved_new sh -c 'grep \"Subject: SPAM: \" /var/mail/localhost.localdomain/user1/new/ -R'"
  assert_success
}
