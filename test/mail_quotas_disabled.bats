load 'test_helper/common'

# Test case
# ---------
# When ENABLE_QUOTAS is explicitly disabled (ENABLE_QUOTAS=0), dovecot quota must not be enabled.


function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    docker run -d --name mail_no_quotas \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e DMS_DEBUG=0 \
		-e ENABLE_QUOTAS=0 \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_no_quotas
}

function teardown_file() {
    docker rm -f mail_no_quotas
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

@test "checking dovecot: (ENABLE_QUOTAS=0) quota plugin is disabled" {
 run docker exec mail_no_quotas /bin/sh -c "grep '\$mail_plugins quota' /etc/dovecot/conf.d/10-mail.conf"
 assert_failure
 run docker exec mail_no_quotas /bin/sh -c "grep '\$mail_plugins imap_quota' /etc/dovecot/conf.d/20-imap.conf"
 assert_failure
 run docker exec mail_no_quotas ls /etc/dovecot/conf.d/90-quota.conf
 assert_failure
 run docker exec mail_no_quotas ls /etc/dovecot/conf.d/90-quota.conf.disab
 assert_success
}

@test "checking postfix: (ENABLE_QUOTAS=0) dovecot quota absent in postconf" {
  run docker exec mail_no_quotas /bin/bash -c "postconf | grep 'check_policy_service inet:localhost:65265'"
  assert_failure
}


@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
