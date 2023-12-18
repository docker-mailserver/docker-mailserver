load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

# This file tests Rspamd when some of its features are enabled, and
# some other interfering features are enabled.
BATS_TEST_NAME_PREFIX='[Rspamd] (partly) '
CONTAINER_NAME='dms-test_rspamd-partly'

function setup_file() {
  _init_with_defaults

  # Comment for maintainers about `PERMIT_DOCKER=host`:
  # https://github.com/docker-mailserver/docker-mailserver/pull/2815/files#r991087509
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_SPAMASSASSIN=1
    --env ENABLE_CLAMAV=0
    --env ENABLE_RSPAMD=1
    --env ENABLE_OPENDKIM=1
    --env ENABLE_OPENDMARC=1
    --env ENABLE_POLICYD_SPF=1
    --env ENABLE_POSTGREY=0
    --env PERMIT_DOCKER=host
    --env LOG_LEVEL=trace
    --env MOVE_SPAM_TO_JUNK=0
    --env RSPAMD_LEARN=0
    --env RSPAMD_CHECK_AUTHENTICATED=1
    --env RSPAMD_GREYLISTING=0
    --env RSPAMD_HFILTER=0
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _wait_for_service rspamd-redis
  _wait_for_service rspamd
  _wait_for_service amavis
  _wait_for_service postfix
  _wait_for_smtp_port_in_container
}

function teardown_file() { _default_teardown ; }

@test "log warns about interfering features" {
  run docker logs "${CONTAINER_NAME}"
  assert_success
  for SERVICE in 'Amavis/SA' 'OpenDKIM' 'OpenDMARC' 'policyd-spf'; do
    assert_output --regexp ".*WARNING.*Running ${SERVICE} & Rspamd at the same time is discouraged"
  done
}

@test 'log shows all features as properly disabled' {
  run docker logs "${CONTAINER_NAME}"
  assert_success
  assert_line --partial 'Rspamd will not use ClamAV (which has not been enabled)'
  assert_line --partial 'Intelligent learning of spam and ham is disabled'
  assert_line --partial 'Greylisting is disabled'
  assert_line --partial 'Disabling Hfilter (group) module'
}

@test 'antivirus maximum size was not adjusted unnecessarily' {
  _run_in_container grep 'max_size = 25000000' /etc/rspamd/local.d/antivirus.conf
  assert_success
}

@test 'learning is properly disabled' {
  for FILE in learn-{ham,spam}.{sieve,svbin}; do
    _run_in_container_bash "[[ -f /usr/lib/dovecot/sieve-pipe/${FILE} ]]"
    assert_failure
  done

  _run_in_container grep 'mail_plugins.*imap_sieve' /etc/dovecot/conf.d/20-imap.conf
  assert_failure
  local SIEVE_CONFIG_FILE='/etc/dovecot/conf.d/90-sieve.conf'
  _run_in_container grep -F 'imapsieve_mailbox1_name = Junk' "${SIEVE_CONFIG_FILE}"
  assert_failure
  _run_in_container grep -F 'imapsieve_mailbox1_causes = COPY' "${SIEVE_CONFIG_FILE}"
  assert_failure
}

@test 'greylisting is properly disabled' {
  _run_in_container grep -F 'enabled = false;' '/etc/rspamd/local.d/greylist.conf'
  assert_success
}

@test 'hfilter group module configuration is deleted' {
  _run_in_container_bash '[[ -f /etc/rspamd/local.d/hfilter_group.conf ]]'
  assert_failure
}

@test 'checks on authenticated users are enabled' {
  local MODULE_FILE='/etc/rspamd/local.d/settings.conf'
  _run_in_container_bash "[[ -f ${MODULE_FILE} ]]"
  assert_success

  _run_in_container grep -E 'authenticated \{' "${MODULE_FILE}"
  assert_failure
}
