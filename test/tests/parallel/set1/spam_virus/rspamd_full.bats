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
    --env SPAM_SUBJECT='[POTENTIAL SPAM] '
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

  # We will send 5 emails:
  #   1. The first ones should pass just fine
  _send_email_with_msgid 'rspamd-test-email-pass'
  _send_email_with_msgid 'rspamd-test-email-pass-gtube' \
    --body 'AJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X'
  #   2. The second one should be rejected (Rspamd-specific GTUBE pattern for rejection)
  _send_spam --expect-rejection
  #   3. The third one should be rejected due to a virus (ClamAV EICAR pattern)
  # shellcheck disable=SC2016
  _send_email_with_msgid 'rspamd-test-email-virus' --expect-rejection \
    --body 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
  #   4. The fourth one will receive an added header (Rspamd-specific GTUBE pattern for adding a spam header)
  #      ref: https://rspamd.com/doc/other/gtube_patterns.html
  _send_email_with_msgid 'rspamd-test-email-header' \
    --body "YJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X"
  #   5. The fifth one will have its subject rewritten, but now spam header is applied.
  _send_email_with_msgid 'rspamd-test-email-rewrite_subject' \
    --body "ZJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X"

  _run_in_container cat /var/log/mail.log
  assert_success
  refute_output --partial 'inet:localhost:11332: Connection refused'
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

@test 'Rspamd base configuration is correct' {
  _run_in_container rspamadm configdump actions
  assert_success
  assert_line 'greylist = 4;'
  assert_line 'reject = 11;'
  assert_line 'add_header = 6;'
  refute_line --regexp 'rewrite_subject = [0-9]+;'
}

@test 'Rspamd Redis configuration is correct' {
  _run_in_container rspamadm configdump redis
  assert_success
  assert_line 'expand_keys = true;'
  assert_line 'servers = "127.0.0.1:6379";'

  _run_in_container rspamadm configdump history_redis
  assert_success
  assert_line 'compress = true;'
  assert_line 'key_prefix = "rs_history{{COMPRESS}}";'
}

@test "contents of '/etc/rspamd/override.d/' are copied" {
  local OVERRIDE_D='/etc/rspamd/override.d'
  _file_exists_in_container "${OVERRIDE_D}/testmodule_complicated.conf"
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
  assert_line --partial "Spam subject is set - the prefix '[POTENTIAL SPAM] ' will be added to spam e-mails"
  assert_line --partial "Found file '/tmp/docker-mailserver/rspamd/custom-commands.conf' - parsing and applying it"
}

@test 'service log exist and contains proper content' {
  _service_log_should_contain_string_regexp 'rspamd' 'rspamd .* is loading configuration'
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
  _service_log_should_contain_string 'rspamd' 'F (no action)'
  _service_log_should_contain_string 'rspamd' 'S (no action)'

  _print_mail_log_for_msgid 'rspamd-test-email-pass'
  assert_output --partial "stored mail into mailbox 'INBOX'"

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new/ 3
}

@test 'detects and rejects spam' {
  _service_log_should_contain_string 'rspamd' 'S (reject)'
  _service_log_should_contain_string 'rspamd' 'reject "Gtube pattern"'

  _print_mail_log_of_queue_id_from_msgid 'dms-test-email-spam'
  assert_output --partial 'milter-reject'
  assert_output --partial '5.7.1 Gtube pattern'

  _print_mail_log_for_msgid 'dms-test-email-spam'
  refute_output --partial "stored mail into mailbox 'INBOX'"
  assert_failure

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new/ 3
}

@test 'detects and rejects virus' {
  _service_log_should_contain_string 'rspamd' 'T (reject)'
  _service_log_should_contain_string 'rspamd' 'reject "ClamAV FOUND VIRUS "Eicar-Signature"'

  _print_mail_log_of_queue_id_from_msgid 'rspamd-test-email-virus'
  assert_output --partial 'milter-reject'
  assert_output --partial '5.7.1 ClamAV FOUND VIRUS "Eicar-Signature"'

  _print_mail_log_for_msgid 'dms-test-email-spam'
  refute_output --partial "stored mail into mailbox 'INBOX'"
  assert_failure

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new/ 3
}

@test 'custom commands work correctly' {
  # check `testmodule1` which should be disabled
  local MODULE_PATH='/etc/rspamd/override.d/testmodule1.conf'
  _file_exists_in_container "${MODULE_PATH}"
  _run_in_container grep -F '# documentation: https://rspamd.com/doc/modules/testmodule1.html' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'enabled = false;' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'someoption = somevalue;' "${MODULE_PATH}"
  assert_failure

  # check `testmodule2` which should be enabled and it should have extra options set
  MODULE_PATH='/etc/rspamd/override.d/testmodule2.conf'
  _file_exists_in_container "${MODULE_PATH}"
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
  _file_exists_in_container "${MODULE_PATH}"
  # shellcheck disable=SC2016
  _run_in_container grep -F 'some very long line with "weird $charact"ers' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F 'and! ano. ther &line' "${MODULE_PATH}"
  assert_success
  _run_in_container grep -F '# some comment' "${MODULE_PATH}"
  assert_success

  # check whether spaces in front of options are handles properly in `testmodule_complicated`
  MODULE_PATH='/etc/rspamd/override.d/testmodule_complicated.conf'
  _file_exists_in_container "${MODULE_PATH}"
  _run_in_container grep -F '    anOption = anotherValue;' "${MODULE_PATH}"

  # check whether controller option was written properly
  MODULE_PATH='/etc/rspamd/override.d/worker-controller.inc'
  _file_exists_in_container "${MODULE_PATH}"
  _run_in_container grep -F 'someOption = someValue42;' "${MODULE_PATH}"
  assert_success

  # check whether controller option was written properly
  MODULE_PATH='/etc/rspamd/override.d/worker-proxy.inc'
  _file_exists_in_container "${MODULE_PATH}"
  _run_in_container grep -F 'abcdefg71 = RAAAANdooM;' "${MODULE_PATH}"
  assert_success

  # check whether basic options are written properly
  MODULE_PATH='/etc/rspamd/override.d/options.inc'
  _file_exists_in_container "${MODULE_PATH}"
  _run_in_container grep -F 'OhMy = "PraiseBeLinters !";' "${MODULE_PATH}"
  assert_success
}

@test 'MOVE_SPAM_TO_JUNK works for Rspamd' {
  _file_exists_in_container /usr/lib/dovecot/sieve-global/after/spam_to_junk.sieve
  _file_exists_in_container /usr/lib/dovecot/sieve-global/after/spam_to_junk.svbin

  _service_log_should_contain_string 'rspamd' 'S (add header)'
  _service_log_should_contain_string 'rspamd' 'add header "Gtube pattern"'

  _print_mail_log_for_msgid 'rspamd-test-email-header'
  assert_output --partial "fileinto action: stored mail into mailbox [SPECIAL-USE \\Junk]"

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new/ 3
  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/.Junk/new/ 1
}

@test 'Rewriting subject works when enforcing it via GTUBE' {
  _service_log_should_contain_string 'rspamd' 'S (rewrite subject)'
  _service_log_should_contain_string 'rspamd' 'rewrite subject "Gtube pattern"'

  _print_mail_log_for_msgid 'rspamd-test-email-rewrite_subject'
  assert_output --partial "stored mail into mailbox 'INBOX'"

  # check that the inbox contains the subject-rewritten e-mail
  _run_in_container_bash "grep --fixed-strings 'Subject: *** SPAM ***' /var/mail/localhost.localdomain/user1/new/*"
  assert_success

  # check that the inbox contains the normal e-mail (that passes just fine)
  _run_in_container_bash "grep --fixed-strings 'Subject: test' /var/mail/localhost.localdomain/user1/new/*"
  assert_success
}

@test 'SPAM_SUBJECT works' {
  _file_exists_in_container /usr/lib/dovecot/sieve-global/before/spam_subject.sieve
  _file_exists_in_container /usr/lib/dovecot/sieve-global/before/spam_subject.svbin

  # we only have one e-mail in the junk folder, hence using '*' is fine
  _run_in_container_bash "grep --fixed-strings 'Subject: [POTENTIAL SPAM]' /var/mail/localhost.localdomain/user1/.Junk/new/*"
  assert_success
}

@test 'RSPAMD_LEARN works' {
  for FILE in learn-{ham,spam}.{sieve,svbin}; do
    _file_exists_in_container "/usr/lib/dovecot/sieve-pipe/${FILE}"
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
  _nc_wrapper 'nc/rspamd_imap_move_to_junk.txt' '0.0.0.0 143'
  sleep 1 # wait for the transaction to finish

  _service_log_should_contain_string 'mail' 'imapsieve: Matched static mailbox rule [1]'
  _service_log_should_not_contain_string 'mail' 'imapsieve: Matched static mailbox rule [2]'

  _show_complete_mail_log
  for LINE in "${LEARN_SPAM_LINES[@]}"; do
    assert_output --partial "${LINE}"
  done

  # Move an email to the "INBOX" folder from "Junk"; there should be two mails
  # in the "Junk" folder, since the second email we sent during setup should
  # have landed in the Junk folder already.
  _nc_wrapper 'nc/rspamd_imap_move_to_inbox.txt' '0.0.0.0 143'
  sleep 1 # wait for the transaction to finish

  _service_log_should_contain_string 'mail' 'imapsieve: Matched static mailbox rule [2]'

  _show_complete_mail_log
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
  _file_exists_in_container "${MODULE_FILE}"

  _run_in_container grep '__TAG__HFILTER_HOSTNAME_UNKNOWN' "${MODULE_FILE}"
  assert_success
  assert_output --partial 'score = 7;'
}

@test 'checks on authenticated users are disabled' {
  local MODULE_FILE='/etc/rspamd/local.d/settings.conf'
  _file_exists_in_container "${MODULE_FILE}"

  _run_in_container grep -E -A 6 'authenticated \{' "${MODULE_FILE}"
  assert_success
  assert_output --partial 'authenticated = yes;'
  assert_output --partial 'groups_enabled = [dkim];'
}
