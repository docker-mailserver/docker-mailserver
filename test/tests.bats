load 'test_helper/common'

IMAGE_NAME=${NAME}
CONTAINER_NAME='mail'

function setup_file() {
  export START_TIME
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")
  mv "${PRIVATE_CONFIG}/user-patches/user-patches.sh" "${PRIVATE_CONFIG}/user-patches.sh"

  # `LOG_LEVEL=debug` required for using `wait_until_change_detection_event_completes()`
  docker run --rm --detach --tty \
    --name "${CONTAINER_NAME}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -v "$(pwd)/test/onedir":/var/mail-state \
    -e ENABLE_AMAVIS=0 \
    -e AMAVIS_LOGLEVEL=2 \
    -e ENABLE_CLAMAV=0 \
    -e ENABLE_MANAGESIEVE=1 \
    -e ENABLE_QUOTAS=1 \
    -e ENABLE_SPAMASSASSIN=0 \
    -e ENABLE_SRS=1 \
    -e ENABLE_UPDATE_CHECK=0 \
    -e LOG_LEVEL='debug' \
    -e PERMIT_DOCKER=host \
    -e PFLOGSUMM_TRIGGER=logrotate \
    -e REPORT_RECIPIENT=user1@localhost.localdomain \
    -e REPORT_SENDER=report1@mail.my-domain.com \
    -e SA_KILL=3.0 \
    -e SA_SPAM_SUBJECT="SPAM: " \
    -e SA_TAG=-5.0 \
    -e SA_TAG2=2.0 \
    -e SPAMASSASSIN_SPAM_TO_INBOX=0 \
    -e SPOOF_PROTECTION=1 \
    -e SSL_TYPE='snakeoil' \
    -e VIRUSMAILS_DELETE_DELAY=7 \
    --hostname mail.my-domain.com \
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)" \
    --health-cmd "ss --listening --tcp | grep -P 'LISTEN.+:smtp' || exit 1" \
    "${IMAGE_NAME}"

  START_TIME=$(date +%s)
  wait_for_finished_setup_in_container "${CONTAINER_NAME}"
  sleep 15

  # wait_for_amavis_port_in_container "${CONTAINER_NAME}"

  # generate accounts after container has been started
  docker run --rm -e MAIL_USER=added@localhost.localdomain -e MAIL_PASS=mypassword -t "${IMAGE_NAME}" /bin/sh -c 'echo "${MAIL_USER}|$(doveadm pw -s SHA512-CRYPT -u ${MAIL_USER} -p ${MAIL_PASS})"' >> "${PRIVATE_CONFIG}/postfix-accounts.cf"
  docker exec "${CONTAINER_NAME}" addmailuser pass@localhost.localdomain 'may be \a `p^a.*ssword'

  # setup sieve
  docker cp "${PRIVATE_CONFIG}/sieve/dovecot.sieve" mail:/var/mail/localhost.localdomain/user1/.dovecot.sieve

  # this relies on the checksum file being updated after all changes have been applied
  wait_until_change_detection_event_completes "${CONTAINER_NAME}"
  wait_for_service "${CONTAINER_NAME}" postfix
  wait_for_service "${CONTAINER_NAME}" dovecot
  wait_for_smtp_port_in_container "${CONTAINER_NAME}"
  # wait_for_amavis_port_in_container "${CONTAINER_NAME}"

  sleep 15

  # The first mail sent leverages an assert for better error output if a failure occurs:
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
  assert_success

  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-virus.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-external.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-local.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-recipient-delimiter.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user2.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user3.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-added.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user-and-cc-local-alias.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-regexp-alias-external.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-regexp-alias-local.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-catchall-local.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/sieve-spam-folder.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/sieve-pipe.txt"
  assert_success
  run docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/non-existing-user.txt"
  assert_success
  run docker exec mail /bin/sh -c "sendmail root < /tmp/docker-mailserver-test/email-templates/root-email.txt"
  assert_success

  sleep 30
  wait_for_empty_mail_queue_in_container "${CONTAINER_NAME}"
}

function teardown_file() {
  docker rm -f "${CONTAINER_NAME}"
}

#
# configuration checks
#

@test "checking configuration: user-patches.sh executed" {
  run docker logs mail
  assert_output --partial "Default user-patches.sh successfully executed"
}

#
# healthcheck
#

# NOTE: Healthcheck defaults an interval of 30 seconds
# If Postfix is temporarily down (eg: restart triggered by `check-for-changes.sh`),
# it may result in a false-positive `unhealthy` state.
# Be careful with re-locating this test if earlier tests could potentially fail it by
# triggering the `changedetector` service.
@test "checking container healthcheck" {
  # ensure, that at least 30 seconds have passed since container start
  while [[ "$(docker inspect --format='{{.State.Health.Status}}' mail)" == "starting" ]]; do
    sleep 1
  done
  run docker inspect --format='{{.State.Health.Status}}' mail
  assert_output "healthy"
  assert_success
}

#
# processes
#

@test "checking process: postfix" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/lib/postfix/sbin/master'"
  assert_success
}

@test "checking process: clamd (is not running)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_failure
}

# @test "checking process: new" {
#   run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/amavisd-new'"
#   assert_success
# }

@test "checking process: opendkim" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/opendkim'"
  assert_success
}

@test "checking process: opendmarc" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/opendmarc'"
  assert_success
}

@test "checking process: fail2ban (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/python3 /usr/bin/fail2ban-server'"
  assert_failure
}

@test "checking process: fetchmail (disabled in default configuration)" {
  run docker exec mail /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/bin/fetchmail'"
  assert_failure
}
