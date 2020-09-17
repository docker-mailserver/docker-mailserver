load 'test_helper/common'

setup() {
    run_setup_file_if_necessary
}

teardown() {
    run_teardown_file_if_necessary
}

setup_file() {
    docker run --rm -d --name mail_disabled_clamav_spamassassin \
		-v "$(duplicate_config_for_container .)":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e ENABLE_CLAMAV=0 \
		-e ENABLE_SPAMASSASSIN=0 \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t ${NAME}
    # TODO: find a better way to know when we have waited long enough
    #       for clamav to should have come up, if it were enabled
    wait_for_smtp_port_in_container mail_disabled_clamav_spamassassin
    docker exec mail_disabled_clamav_spamassassin /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
}

teardown_file() {
    docker rm -f mail_disabled_clamav_spamassassin
}

@test "first" {
    skip 'only used to call setup_file from setup'
}

@test "checking process: clamav (clamav disabled by ENABLED_CLAMAV=0)" {
  run docker exec mail_disabled_clamav_spamassassin /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_failure
}

@test "checking spamassassin: should not be listed in amavis when disabled" {
  run docker exec mail_disabled_clamav_spamassassin /bin/sh -c "grep -i 'ANTI-SPAM-SA code' /var/log/mail/mail.log | grep 'NOT loaded'"
  assert_success
}

@test "checking clamav: should not be listed in amavis when disabled" {
  run docker exec mail_disabled_clamav_spamassassin grep -i 'Found secondary av scanner ClamAV-clamscan' /var/log/mail/mail.log
  assert_failure
}

@test "checking clamav: should not be called when disabled" {
  run docker exec mail_disabled_clamav_spamassassin grep -i 'connect to /var/run/clamav/clamd.ctl failed' /var/log/mail/mail.log
  assert_failure
}

@test "checking restart of process: clamav (clamav disabled by ENABLED_CLAMAV=0)" {
  run docker exec mail_disabled_clamav_spamassassin /bin/bash -c "pkill -f clamd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/clamd'"
  assert_failure
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}
