load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

# This file tests Rspamd when all of its features are enabled, and
# all other interfering features are disabled.
BATS_TEST_NAME_PREFIX='[Rspamd] (full) '
CONTAINER_NAME='dms-test_rspamd-full'

function setup_file() {
  _init_with_defaults

  # Comment for maintainers about `PERMIT_DOCKER=host`:
  # https://github.com/docker-mailserver/docker-mailserver/pull/2815/files#r991087509
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=0
    --env ENABLE_SPAMASSASSIN=0
    --env ENABLE_CLAMAV=1
    --env ENABLE_RSPAMD=1
    --env ENABLE_OPENDKIM=0
    --env ENABLE_OPENDMARC=0
    --env ENABLE_POLICYD_SPF=0
    --env ENABLE_POSTGREY=0
    --env CLAMAV_MESSAGE_SIZE_LIMIT=42M
    --env PERMIT_DOCKER=host
    --env LOG_LEVEL=trace
    --env MOVE_SPAM_TO_JUNK=1
    --env RSPAMD_LEARN=1
    --env RSPAMD_CHECK_AUTHENTICATED=0
    --env RSPAMD_GREYLISTING=1
    --env RSPAMD_HFILTER=1
    --env RSPAMD_HFILTER_HOSTNAME_UNKNOWN_SCORE=7
  )

  cp -r "${TEST_TMP_CONFIG}"/rspamd_full/* "${TEST_TMP_CONFIG}/"
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # wait for ClamAV to be fully setup or we will get errors on the log
  _repeat_in_container_until_success_or_timeout 60 "${CONTAINER_NAME}" test -e /var/run/clamav/clamd.ctl

  _wait_for_service rspamd-redis
  _wait_for_service rspamd
  _wait_for_service clamav
  _wait_for_service postfix
  _wait_for_smtp_port_in_container

  # We will send 3 emails: the first one should pass just fine; the second one should
  # be rejected due to spam; the third one should be rejected due to a virus.
  export MAIL_ID1=$(_send_email_and_get_id 'email-templates/rspamd-pass')
  export MAIL_ID2=$(_send_email_and_get_id 'email-templates/rspamd-spam')
  export MAIL_ID3=$(_send_email_and_get_id 'email-templates/rspamd-virus')
  export MAIL_ID4=$(_send_email_and_get_id 'email-templates/rspamd-spam-header')

  for ID in MAIL_ID{1,2,3,4}; do
    [[ -n ${!ID} ]] || { echo "${ID} is empty - aborting!" ; return 1 ; }
  done
}

function teardown_file() { _default_teardown ; }

@test "Postfix's main.cf was adjusted" {
  # shellcheck disable=SC2016
  _run_in_container grep -F 'smtpd_milters = $rspamd_milter' /etc/postfix/main.cf
  assert_success
  _run_in_container postconf rspamd_milter
  assert_success
  assert_output 'rspamd_milter = inet:localhost:11332'
}

@test "'/etc/rspamd/override.d/' is linked correctly" {
  local OVERRIDE_D='/etc/rspamd/override.d'

  _run_in_container_bash "[[ -h ${OVERRIDE_D} ]]"
  assert_success

  _run_in_container_bash "[[ -f ${OVERRIDE_D}/testmodule_complicated.conf ]]"
  assert_success
}

@test 'startup log shows all features as properly enabled' {
  run docker logs "${CONTAINER_NAME}"
  assert_success
  assert_line --partial 'Enabling ClamAV integration'
  assert_line --partial 'Adjusting maximum size for ClamAV to 42000000 bytes (42M)'
  assert_line --partial 'Setting up intelligent learning of spam and ham'
  assert_line --partial 'Enabling greylisting'
  assert_line --partial 'Hfilter (group) module is enabled'
  assert_line --partial "Adjusting score for 'HFILTER_HOSTNAME_UNKNOWN' in Hfilter group module to"
  assert_line --partial "Found file '/tmp/docker-mailserver/rspamd/custom-commands.conf' - parsing and applying it"
}

@test 'service log exist and contains proper content' {
  _service_log_should_contain_string 'rspamd' 'rspamd .* is loading configuration'
  _service_log_should_contain_string 'rspamd' 'lua module clickhouse is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module elastic is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module neural is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module reputation is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module spamassassin is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module url_redirector is disabled in the configuration'
  _service_log_should_contain_string 'rspamd' 'lua module metric_exporter is disabled in the configuration'
}

@test 'antivirus maximum size was adjusted' {
  _run_in_container grep 'max_size = 42000000' /etc/rspamd/local.d/antivirus.conf
  assert_success
}

@test 'normal mail passes fine' {
  _service_log_should_contain_string 'rspamd' 'F \(no action\)'

  _print_mail_log_for_id "${MAIL_ID1}"
  assert_output --partial "stored mail into mailbox 'INBOX'"

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new/ 1
}

@test 'detects and rejects spam' {
  _service_log_should_contain_string 'rspamd' 'S \(reject\)'
  _service_log_should_contain_string 'rspamd' 'reject "Gtube pattern"'

  _print_mail_log_for_id "${MAIL_ID2}"
  assert_output --partial 'milter-reject'
  assert_output --partial '5.7.1 Gtube pattern'

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new/ 1
}

@test 'detects and rejects virus' {
  _service_log_should_contain_string 'rspamd' 'T \(reject\)'
  _service_log_should_contain_string 'rspamd' 'reject "ClamAV FOUND VIRUS "Eicar-Signature"'

  _print_mail_log_for_id "${MAIL_ID3}"
  assert_output --partial 'milter-reject'
  assert_output --partial '5.7.1 ClamAV FOUND VIRUS "Eicar-Signature"'
  refute_output --partial "stored mail into mailbox 'INBOX'"

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new/ 1
}

@test 'custom commands work correctly' {
  # check `testmodule1` which should be disabled
  local MODULE_PATH='/etc/rspamd/override.d/testmodule1.conf'
  _run_in_container_bash "[[ -f ${MODULE_PATH} ]]"
  assert_success
  _run_in_container grep -F '# documentation: https://rspamd.com/doc/modules/testmodule1.html' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'enabled = false;' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'someoption = somevalue;' "${MODULE_PATH}"
  assert_failure

  # check `testmodule2` which should be enabled and it should have extra options set
  MODULE_PATH='/etc/rspamd/override.d/testmodule2.conf'
  _run_in_container_bash "[[ -f ${MODULE_PATH} ]]"
  assert_success
  _run_in_container grep -F '# documentation: https://rspamd.com/doc/modules/testmodule2.html' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'enabled = true;' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'someoption = somevalue;' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'anotheroption = whatAvaLue;' "${MODULE_PATH}"
  assert_success

  # check whether writing the same option twice overwrites the first value in `testmodule3`
  MODULE_PATH='/etc/rspamd/override.d/testmodule3.conf'
  _run_in_container grep -F 'someoption = somevalue;' "${MODULE_PATH}"
  assert_failure
  _run_in_container grep -F 'someoption = somevalue2;' "${MODULE_PATH}"
  assert_success

  # check whether adding a single line writes the line properly in `testmodule4.something`
  MODULE_PATH='/etc/rspamd/override.d/testmodule4.something'
  _run_in_container_bash "[[ -f ${MODULE_PATH} ]]"
  assert_success
  # shellcheck disable=SC2016
  _run_in_container grep -F 'some very long line with "weird $charact"ers' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'and! ano. ther &line' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F '# some comment' "${MODULE_PATH}"
  assert_success

  # check whether spaces in front of options are handles properly in `testmodule_complicated`
  MODULE_PATH='/etc/rspamd/override.d/testmodule_complicated.conf'
  _run_in_container_bash "[[ -f ${MODULE_PATH} ]]"
  assert_success
  _run_in_container grep -F '    anOption = anotherValue;' "${MODULE_PATH}"

  # check whether controller option was written properly
  MODULE_PATH='/etc/rspamd/override.d/worker-controller.inc'
  _run_in_container_bash "[[ -f ${MODULE_PATH} ]]"
  assert_success
  _run_in_container grep -F 'someOption = someValue42;' "${MODULE_PATH}"
  assert_success

  # check whether controller option was written properly
  MODULE_PATH='/etc/rspamd/override.d/worker-proxy.inc'
  _run_in_container_bash "[[ -f ${MODULE_PATH} ]]"
  assert_success
  _run_in_container grep -F 'abcdefg71 = RAAAANdooM;' "${MODULE_PATH}"
  assert_success

  # check whether basic options are written properly
  MODULE_PATH='/etc/rspamd/override.d/options.inc'
  _run_in_container_bash "[[ -f ${MODULE_PATH} ]]"
  assert_success
  _run_in_container grep -F 'OhMy = "PraiseBeLinters !";' "${MODULE_PATH}"
  assert_success
}

@test 'MOVE_SPAM_TO_JUNK works for Rspamd' {
  _run_in_container_bash '[[ -f /usr/lib/dovecot/sieve-global/after/spam_to_junk.sieve ]]'
  assert_success
  _run_in_container_bash '[[ -f /usr/lib/dovecot/sieve-global/after/spam_to_junk.svbin ]]'
  assert_success

  _service_log_should_contain_string 'rspamd' 'S \(add header\)'
  _service_log_should_contain_string 'rspamd' 'add header "Gtube pattern"'

  _print_mail_log_for_id "${MAIL_ID4}"
  assert_output --partial "fileinto action: stored mail into mailbox 'Junk'"

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new/ 1
  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/.Junk/new/ 1
}

@test 'RSPAMD_LEARN works' {
  for FILE in learn-{ham,spam}.{sieve,svbin}; do
    _run_in_container_bash "[[ -f /usr/lib/dovecot/sieve-pipe/${FILE} ]]"
    assert_success
  done

  _run_in_container grep 'mail_plugins.*imap_sieve' /etc/dovecot/conf.d/20-imap.conf
  assert_success
  local SIEVE_CONFIG_FILE='/etc/dovecot/conf.d/90-sieve.conf'
  _run_in_container grep 'sieve_plugins.*sieve_imapsieve' "${SIEVE_CONFIG_FILE}"
  assert_success
  _run_in_container grep -F 'sieve_pipe_bin_dir = /usr/lib/dovecot/sieve-pipe' "${SIEVE_CONFIG_FILE}"
  assert_success

  local LEARN_SPAM_LINES=(
    'imapsieve: mailbox Junk: MOVE event'
    "sieve: file storage: script: Opened script \`learn-spam'"
    'sieve: file storage: Using Sieve script path: /usr/lib/dovecot/sieve-pipe/learn-spam.sieve'
    "sieve: Executing script from \`/usr/lib/dovecot/sieve-pipe/learn-spam.svbin'"
    "Finished running script \`/usr/lib/dovecot/sieve-pipe/learn-spam.svbin'"
    'sieve: action pipe: running program: rspamc'
    "pipe action: piped message to program \`rspamc'"
    "left message in mailbox 'Junk'"
  )

  local LEARN_HAM_LINES=(
    "sieve: file storage: script: Opened script \`learn-ham'"
    'sieve: file storage: Using Sieve script path: /usr/lib/dovecot/sieve-pipe/learn-ham.sieve'
    "sieve: Executing script from \`/usr/lib/dovecot/sieve-pipe/learn-ham.svbin'"
    "Finished running script \`/usr/lib/dovecot/sieve-pipe/learn-ham.svbin'"
    "left message in mailbox 'INBOX'"
  )

  # Move an email to the "Junk" folder from "INBOX"; the first email we
  # sent should pass fine, hence we can now move it.
  _send_email 'nc_templates/rspamd_imap_move_to_junk' '0.0.0.0 143'
  sleep 1 # wait for the transaction to finish

  _run_in_container cat /var/log/mail/mail.log
  assert_success
  assert_output --partial 'imapsieve: Matched static mailbox rule [1]'
  refute_output --partial 'imapsieve: Matched static mailbox rule [2]'
  for LINE in "${LEARN_SPAM_LINES[@]}"; do
    assert_output --partial "${LINE}"
  done

  # Move an email to the "INBOX" folder from "Junk"; there should be two mails
  # in the "Junk" folder, since the second email we sent during setup should
  # have landed in the Junk folder already.
  _send_email 'nc_templates/rspamd_imap_move_to_inbox' '0.0.0.0 143'
  sleep 1 # wait for the transaction to finish

  _run_in_container cat /var/log/mail/mail.log
  assert_success
  assert_output --partial 'imapsieve: Matched static mailbox rule [2]'
  for LINE in "${LEARN_HAM_LINES[@]}"; do
    assert_output --partial "${LINE}"
  done
}

@test 'greylisting is enabled' {
  _run_in_container grep 'enabled = true;' /etc/rspamd/local.d/greylist.conf
  assert_success
  _run_in_container rspamadm configdump greylist
  assert_success
  assert_output --partial 'enabled = true;'
}

@test 'hfilter group module is configured correctly' {
  local MODULE_FILE='/etc/rspamd/local.d/hfilter_group.conf'
  _run_in_container_bash "[[ -f ${MODULE_FILE} ]]"
  assert_success

  _run_in_container grep '__TAG__HFILTER_HOSTNAME_UNKNOWN' "${MODULE_FILE}"
  assert_success
  assert_output --partial 'score = 7;'
}

@test 'checks on authenticated users are disabled' {
  local MODULE_FILE='/etc/rspamd/local.d/settings.conf'
  _run_in_container_bash "[[ -f ${MODULE_FILE} ]]"
  assert_success

  _run_in_container grep -E -A 6 'authenticated \{' "${MODULE_FILE}"
  assert_success
  assert_output --partial 'authenticated = yes;'
  assert_output --partial 'groups_enabled = [];'
}
