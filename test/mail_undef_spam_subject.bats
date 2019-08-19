load 'test_helper/common'

function setup() {
    docker run -d --name mail_undef_spam_subject \
            -v "`pwd`/test/config":/tmp/docker-mailserver \
            -v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
            -e ENABLE_SPAMASSASSIN=1 \
            -e SA_SPAM_SUBJECT="undef" \
            -h mail.my-domain.com -t ${NAME}
    CONTAINER=$(docker run -d \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-v "`pwd`/test/onedir":/var/mail-state \
		-e ENABLE_CLAMAV=1 \
		-e SPOOF_PROTECTION=1 \
		-e ENABLE_SPAMASSASSIN=1 \
		-e REPORT_RECIPIENT=user1@localhost.localdomain \
		-e REPORT_SENDER=report1@mail.my-domain.com \
		-e SA_TAG=-5.0 \
		-e SA_TAG2=2.0 \
		-e SA_KILL=3.0 \
		-e SA_SPAM_SUBJECT="SPAM: " \
		-e VIRUSMAILS_DELETE_DELAY=7 \
		-e ENABLE_SRS=1 \
		-e SASL_PASSWD="external-domain.com username:password" \
		-e ENABLE_MANAGESIEVE=1 \
		--cap-add=SYS_PTRACE \
		-e PERMIT_DOCKER=host \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t ${NAME})
    wait_for_finished_setup_in_container mail_undef_spam_subject
    wait_for_finished_setup_in_container "$CONTAINER"
}

function teardown() {
    docker rm -f mail_undef_spam_subject "$CONTAINER"
}

@test "checking spamassassin: docker env variables are set correctly (custom)" {
  run docker exec "$CONTAINER" /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= -5.0'"
  assert_success
  run docker exec "$CONTAINER" /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  assert_success
  run docker exec "$CONTAINER" /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 3.0'"
  assert_success
  run docker exec "$CONTAINER" /bin/sh -c "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= .SPAM: .'"
  assert_success
  run docker exec mail_undef_spam_subject /bin/sh -c "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= undef'"
  assert_success
}