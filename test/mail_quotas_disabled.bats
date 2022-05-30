load 'test_helper/common'

# Test case
# ---------
# When ENABLE_QUOTAS is explicitly disabled (ENABLE_QUOTAS=0), dovecot quota must not be enabled.


function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_no_quotas \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_QUOTAS=0 \
    -h mail.my-domain.com -t "${NAME}"

  wait_for_finished_setup_in_container mail_no_quotas
}

function teardown_file() {
  docker rm -f mail_no_quotas
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

