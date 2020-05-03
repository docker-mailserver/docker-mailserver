load 'test_helper/common'

# Test case
# ---------
# When SPAMASSASSIN_SPAM_TO_INBOX=1, spam messages must be delivered and eventually (MOVE_SPAM_TO_JUNK=1) moved to the Junk folder.


function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    docker run -d --name mail_spam_moved_junk \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e ENABLE_SPAMASSASSIN=1 \
		-e SPAMASSASSIN_SPAM_TO_INBOX=1 \
		-e MOVE_SPAM_TO_JUNK=1 \
		-e SA_SPAM_SUBJECT="SPAM: " \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_spam_moved_junk

    docker run -d --name mail_spam_moved_new \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e ENABLE_SPAMASSASSIN=1 \
		-e SPAMASSASSIN_SPAM_TO_INBOX=1 \
		-e MOVE_SPAM_TO_JUNK=0 \
		-e SA_SPAM_SUBJECT="SPAM: " \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_spam_moved_new
}

function teardown_file() {
    docker rm -f mail_spam_moved_new
    docker rm -f mail_spam_moved_junk
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking amavis: spam message is delivered and moved to the Junk folder (MOVE_SPAM_TO_JUNK=1)" {
  # send a spam message
  run docker exec mail_spam_moved_junk /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  run repeat_until_success_or_timeout 20 sh -c "docker logs mail_spam_moved_junk | grep 'Passed SPAM {RelayedTaggedInbound,Quarantined}'"
  assert_success

  # spam moved to Junk folder
  run repeat_until_success_or_timeout 20 sh -c "docker exec mail_spam_moved_junk sh -c 'grep \"Subject: SPAM: \" /var/mail/localhost.localdomain/user1/.Junk/new/ -R'"
  assert_success
}

@test "checking amavis: spam message is delivered to INBOX (MOVE_SPAM_TO_JUNK=0)" {
  # send a spam message
  run docker exec mail_spam_moved_new /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  run repeat_until_success_or_timeout 20 sh -c "docker logs mail_spam_moved_new | grep 'Passed SPAM {RelayedTaggedInbound,Quarantined}'"
  assert_success

  # spam moved to INBOX
  run repeat_until_success_or_timeout 20 sh -c "docker exec mail_spam_moved_new sh -c 'grep \"Subject: SPAM: \" /var/mail/localhost.localdomain/user1/new/ -R'"
  assert_success
}

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
