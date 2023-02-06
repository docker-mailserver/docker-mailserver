load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Rspamd] '
CONTAINER_NAME='dms-test_rspamd'

function setup_file() {
  _init_with_defaults

  # Comment for maintainers about `PERMIT_DOCKER=host`:
  # https://github.com/docker-mailserver/docker-mailserver/pull/2815/files#r991087509
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_CLAMAV=1
    --env ENABLE_RSPAMD=1
    --env ENABLE_OPENDKIM=0
    --env ENABLE_OPENDMARC=0
    --env PERMIT_DOCKER=host
    --env LOG_LEVEL=trace
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # wait for ClamAV to be fully setup or we will get errors on the log
  _repeat_in_container_until_success_or_timeout 60 "${CONTAINER_NAME}" test -e /var/run/clamav/clamd.ctl

  _wait_for_service redis
  _wait_for_service rspamd
  _wait_for_service postfix
  _wait_for_smtp_port_in_container

  # We will send 3 emails: the first one should pass just fine; the second one should
  # be rejected due to spam; the third one should be rejected due to a virus.
  export MAIL_ID1=$(_send_mail_and_get_id 'existing-user1')
  export MAIL_ID2=$(_send_mail_and_get_id 'rspamd-spam')
  export MAIL_ID3=$(_send_mail_and_get_id 'rspamd-virus')

  # add a nested option to a module
  _exec_in_container_bash "echo -e 'complicated {\n    anOption = someValue;\n}' >/etc/rspamd/override.d/testmodule_complicated.conf"
}

function teardown_file() { _default_teardown ; }

@test 'Postfix's main.cf was adjusted' {
  _run_in_container grep -q 'smtpd_milters = inet:localhost:11332' /etc/postfix/main.cf
  assert_success
}

@test 'logs exist and contains proper content' {
  _service_log_should_contain_string 'rspamd' 'rspamd .* is loading configuration'
  _service_log_should_contain_string 'rspamd' 'lua module clickhouse is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module elastic is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module neural is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module reputation is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module spamassassin is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module url_redirector is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module metric_exporter is disabled in the configuration'
}

@test 'normal mail passes fine' {
  _service_log_should_contain_string 'rspamd' 'F \(no action\)'

  _print_mail_log_for_id "${MAIL_ID1}"
  assert_output --partial "stored mail into mailbox 'INBOX'"
}

@test 'detects and rejects spam' {
  _service_log_should_contain_string 'rspamd' 'S \(reject\)'
  _service_log_should_contain_string 'rspamd' 'reject "Gtube pattern"'

  _print_mail_log_for_id "${MAIL_ID2}"
  assert_output --partial 'milter-reject'
  assert_output --partial '5.7.1 Gtube pattern'
}

@test 'detects and rejects virus' {
  _service_log_should_contain_string 'rspamd' 'T \(reject\)'
  _service_log_should_contain_string 'rspamd' 'reject "ClamAV FOUND VIRUS "Eicar-Signature"'

  _print_mail_log_for_id "${MAIL_ID3}"
  assert_output --partial 'milter-reject'
  assert_output --partial '5.7.1 ClamAV FOUND VIRUS "Eicar-Signature"'
  refute_output --partial "stored mail into mailbox 'INBOX'"
}

@test 'custom commands work correctly' {
  # check all positive cases first that should not fail at all
  _run_in_container_bash '[[ -f /etc/rspamd/override.d/testmodule1.conf ]]'
  assert_success
  _run_in_container grep -F '# documentation: https://rspamd.com/doc/modules/someWeirdName.html' /etc/rspamd/override.d/testmodule1.conf
  assert_success
  _run_in_container grep -F 'enabled = false;' /etc/rspamd/override.d/testmodule1.conf
  assert_success
  _run_in_container grep -F 'someoption = somevalue;' /etc/rspamd/override.d/testmodule1.conf
  assert_failure

  _run_in_container_bash '[[ -f /etc/rspamd/override.d/testmodule2.conf ]]'
  assert_success
  _run_in_container grep -F '# documentation: https://rspamd.com/doc/modules/testmodule2.html' /etc/rspamd/override.d/testmodule2.conf
  assert_success
  _run_in_container grep -F 'enabled = true;' /etc/rspamd/override.d/testmodule2.conf
  assert_success
  _run_in_container grep -F 'someoption = somevalue;' /etc/rspamd/override.d/testmodule2.conf
  assert_success
  _run_in_container grep -F 'anotheroption = whatAvaLue;' /etc/rspamd/override.d/testmodule2.conf
  assert_success

  # check whether writing the same option twice overwrites the first value
  _run_in_container grep -F 'someoption = somevalue;' /etc/rspamd/override.d/testmodule3.conf
  assert_failure
  _run_in_container grep -F 'someoption = somevalue2;' /etc/rspamd/override.d/testmodule3.conf
  assert_success

  # check whether adding a single line writes the line properly
  _run_in_container_bash '[[ -f /etc/rspamd/override.d/testmodule4.conf ]]'
  assert_success
  _run_in_container grep -F 'some very long line with "weird $characters' /etc/rspamd/override.d/testmodule4.conf
  assert_success
  _run_in_container grep -F 'and! ano. ther &line' /etc/rspamd/override.d/testmodule4.conf
  assert_success
  _run_in_container grep -F '# some comment' /etc/rspamd/override.d/testmodule4.conf
  assert_success

  # check whether spaces in front of options are handles properly
  _run_in_container grep -F '    anOption = anotherValue;' /etc/rspamd/override.d/testmodule_complicated.conf
}
