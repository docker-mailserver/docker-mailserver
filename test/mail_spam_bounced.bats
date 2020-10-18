load 'test_helper/common'

# Test case
# ---------
# When SPAMASSASSIN_SPAM_TO_INBOX=0, spam messages must be bounced.


function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    docker run -d --name mail_spam_bounced_defined \
		-v "$(duplicate_config_for_container . mail_spam_bounced_defined)":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e ENABLE_SPAMASSASSIN=1 \
		-e SPAMASSASSIN_SPAM_TO_INBOX=0 \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_spam_bounced_defined

    docker run -d --name mail_spam_bounced_undefined \
		-v "$(duplicate_config_for_container . mail_spam_bounced_defined)":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e ENABLE_SPAMASSASSIN=1 \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_spam_bounced_undefined
}

function teardown_file() {
    docker rm -f mail_spam_bounced_defined
    docker rm -f mail_spam_bounced_undefined
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking amavis: spam message is bounced" {
  # this warning should only be raised when no explicit value for SPAMASSASSIN_SPAM_TO_INBOX is defined
  run sh -c "docker logs mail_spam_bounced_defined | grep 'Spam messages WILL NOT BE DELIVERED'"
  assert_failure

  # send a spam message
  run docker exec mail_spam_bounced_defined /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  run repeat_until_success_or_timeout 20 sh -c "docker logs mail_spam_bounced_defined | grep 'Blocked SPAM {NoBounceInbound,Quarantined}'"
  assert_success
}

@test "checking amavis: spam message is bounced, undefined SPAMASSASSIN_SPAM_TO_INBOX raise a warning" {
  run sh -c "docker logs mail_spam_bounced_undefined | grep 'Spam messages WILL NOT BE DELIVERED'"
  assert_success

  # send a spam message
  run docker exec mail_spam_bounced_defined /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  run repeat_until_success_or_timeout 20 sh -c "docker logs mail_spam_bounced_defined | grep 'Blocked SPAM {NoBounceInbound,Quarantined}'"
  assert_success
}

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
