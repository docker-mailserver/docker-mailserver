load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Configuration] (overrides) '
CONTAINER_NAME='dms-test_config-overrides'

function setup_file() {
  _init_with_defaults

  # Move override configs into main `/tmp/docker-mailserver` config location:
  mv "${TEST_TMP_CONFIG}/override-configs/"* "${TEST_TMP_CONFIG}/"

  _common_container_setup
}

function teardown_file() { _default_teardown ; }

# The `postconf` command can query both `main.cf` and `master.cf` at `/etc/postfix/`.
# Reference: http://www.postfix.org/postconf.1.html

@test "Postfix - 'postfix-main.cf' overrides applied to '/etc/postfix/main.cf'" {
  _run_in_container grep -q 'max_idle = 600s' /tmp/docker-mailserver/postfix-main.cf
  assert_success

  _run_in_container grep -q 'readme_directory = /tmp' /tmp/docker-mailserver/postfix-main.cf
  assert_success

  _run_in_container postconf
  assert_success
  assert_output --partial 'max_idle = 600s'
  assert_output --partial 'readme_directory = /tmp'
}

@test "Postfix - 'postfix-master.cf' overrides applied to '/etc/postfix/master.cf'" {
  _run_in_container grep -q 'submission/inet/smtpd_sasl_security_options=noanonymous' /tmp/docker-mailserver/postfix-master.cf
  assert_success

  _run_in_container postconf -M
  assert_success
  assert_output --partial '-o smtpd_sasl_security_options=noanonymous'
}

# Custom parameter support works correctly:
# NOTE: This would only fail on a fresh container state, any restart would pass successfully:
# https://github.com/docker-mailserver/docker-mailserver/pull/3880
@test "Postfix - 'postfix-master.cf' should apply before 'postfix-main.cf'" {
  # Retrieve the value for this setting, `postfix-master.cf` should have the override set:
  _run_in_container postconf -Ph 'submission/inet/smtpd_client_restrictions'
  assert_success
  refute_output --partial 'postconf: warning: /etc/postfix/master.cf: undefined parameter: custom_parameter'
  #shellcheck disable=SC2016
  assert_output '$custom_parameter'

  # As it's a custom parameter (`$` prefix), ensure the parameter value expands correctly:
  _run_in_container postconf -Phx 'submission/inet/smtpd_client_restrictions'
  assert_success
  refute_output --partial 'postconf: warning: /etc/postfix/master.cf: undefined parameter: custom_parameter'
  assert_output 'cidr:{{!172.16.0.42 REJECT}}, permit_sasl_authenticated, reject'
}

@test "Dovecot - 'dovecot.cf' overrides applied to '/etc/dovecot/local.conf'" {
  _run_in_container grep -q 'mail_max_userip_connections = 69' /tmp/docker-mailserver/dovecot.cf
  assert_success

  _run_in_container doveconf
  assert_success
  assert_output --partial 'mail_max_userip_connections = 69'
}
