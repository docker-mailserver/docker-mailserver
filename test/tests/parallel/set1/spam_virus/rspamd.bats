load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[rspamd] '
CONTAINER_NAME='dms-test_rspamd'

function setup_file() {
  _init_with_defaults

  # Comment for maintainers about `PERMIT_DOCKER=host`:
  # https://github.com/docker-mailserver/docker-mailserver/pull/2815/files#r991087509
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_CLAMAV=1
    --env ENABLE_RSPAMD=1
    --env CLAMAV_MESSAGE_SIZE_LIMIT=30M
    --env ENABLE_OPENDKIM=0
    --env ENABLE_OPENDMARC=0
    --env PERMIT_DOCKER=host
    --env LOG_LEVEL=trace
    -p 11334:11334
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
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/rspamd-spam.txt"
  assert_success
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/rspamd-virus.txt"
  assert_success

  _wait_for_empty_mail_queue_in_container "${CONTAINER_NAME}"
}

function teardown_file() { _default_teardown ; }

@test "Postfix's main.cf was adjusted" {
  _run_in_container grep -q 'smtpd_milters = inet:localhost:11332' /etc/postfix/main.cf
  assert_success
}

@test "logs exist and contains proper content" {
  _should_contain_string_rspamd 'rspamd .* is loading configuration'
  _should_contain_string_rspamd 'lua module clickhouse is disabled in the configuration'
  _should_contain_string_rspamd 'lua module dkim_signing is disabled in the configuration'
  _should_contain_string_rspamd 'lua module elastic is disabled in the configuration'
  _should_contain_string_rspamd 'lua module rbl is disabled in the configuration'
  _should_contain_string_rspamd 'lua module reputation is disabled in the configuration'
  _should_contain_string_rspamd 'lua module spamassassin is disabled in the configuration'
  _should_contain_string_rspamd 'lua module url_redirector is disabled in the configuration'
  _should_contain_string_rspamd 'lua module metric_exporter is disabled in the configuration'
}

@test "normal mail passes fine" {
  _should_contain_string_rspamd 'F (no action)'

  run docker logs -n 100 "${CONTAINER_NAME}"
  assert_success
  assert_output --partial "stored mail into mailbox 'INBOX'"
}

@test "detects and rejects spam" {
  _should_contain_string_rspamd 'S (reject)'
  _should_contain_string_rspamd 'reject "Gtube pattern"'

  run docker logs -n 100 "${CONTAINER_NAME}"
  assert_success
  assert_output --partial 'milter-reject'
  assert_output --partial '5.7.1 Gtube pattern'
}

@test "detects and rejects virus" {
  _should_contain_string_rspamd 'T (reject)'
  _should_contain_string_rspamd 'reject "ClamAV FOUND VIRUS "Eicar-Signature"'

  run docker logs -n 8 "${CONTAINER_NAME}"
  assert_success
  assert_output --partial 'milter-reject'
  assert_output --partial '5.7.1 ClamAV FOUND VIRUS "Eicar-Signature"'
  refute_output --partial "stored mail into mailbox 'INBOX'"
}

function _should_contain_string_rspamd() {
  local STRING=${1:?No string provided to _should_contain_string_rspamd}

  _run_in_container grep -q "${STRING}" /var/log/supervisor/rspamd.log
  assert_success
}
