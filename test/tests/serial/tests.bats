load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/change-detection"
load "${REPOSITORY_ROOT}/test/helper/setup"

# TODO: These tests date back to the very beginning of DMS and therefore
# TODO: lack the more advanced test suite functions that make tests more
# TODO: robust. As a consequence, the tests should be adjusted.

BATS_TEST_NAME_PREFIX='[General] '
CONTAINER_NAME='mail'

function setup_file() {
  _init_with_defaults

  mv "${TEST_TMP_CONFIG}/user-patches/user-patches.sh" "${TEST_TMP_CONFIG}/user-patches.sh"

  local CONTAINER_ARGS_ENV_CUSTOM=(
    --env ENABLE_AMAVIS=1
    --env AMAVIS_LOGLEVEL=2
    --env ENABLE_QUOTAS=1
    --env ENABLE_SRS=1
    --env PERMIT_DOCKER=host
    --env PFLOGSUMM_TRIGGER=logrotate
    --env REPORT_RECIPIENT=user1@localhost.localdomain
    --env REPORT_SENDER=report1@mail.example.test
    --env SPOOF_PROTECTION=1
    --env SSL_TYPE='snakeoil'
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
    --health-cmd "ss --listening --tcp | grep -P 'LISTEN.+:smtp' || exit 1"
  )
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  _add_mail_account_then_wait_until_ready 'added@localhost.localdomain' 'mypassword'

  _wait_for_service postfix
  _wait_for_smtp_port_in_container
}

function teardown_file() { _default_teardown ; }

#
# configuration checks
#

@test "configuration: user-patches.sh executed" {
  run docker logs "${CONTAINER_NAME}"
  assert_output --partial "Default user-patches.sh successfully executed"
}

@test "configuration: hostname/domainname" {
  run docker run "${IMAGE_NAME:?}"
  assert_success
}

#
# healthcheck
#

# NOTE: Healthcheck defaults an interval of 30 seconds
# If Postfix is temporarily down (eg: restart triggered by `check-for-changes.sh`),
# it may result in a false-positive `unhealthy` state.
# Be careful with re-locating this test if earlier tests could potentially fail it by
# triggering the `changedetector` service.
@test "container healthcheck" {
  # ensure, that at least 30 seconds have passed since container start
  while [[ "$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}")" == "starting" ]]; do
    sleep 1
  done
  run docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}"
  assert_output "healthy"
  assert_success
}

#
# imap
#

@test "imap: server is ready with STARTTLS" {
  _run_in_container_bash "nc -w 2 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'ready'"
  assert_success
}

@test "imap: authentication works" {
  _send_email 'auth/imap-auth' '-w 1 0.0.0.0 143'
}

@test "imap: added user authentication works" {
  _send_email 'auth/added-imap-auth' '-w 1 0.0.0.0 143'
}

#
# sasl
#

@test "sasl: doveadm auth test works with good password" {
  _run_in_container_bash "doveadm auth test -x service=smtp user2@otherdomain.tld mypassword | grep 'auth succeeded'"
  assert_success
}

@test "sasl: doveadm auth test fails with bad password" {
  _run_in_container_bash "doveadm auth test -x service=smtp user2@otherdomain.tld BADPASSWORD | grep 'auth failed'"
  assert_success
}

#
# logs
#

@test "logs: mail related logs should be located in a subdirectory" {
  _run_in_container_bash "ls -1 /var/log/mail/ | grep -E 'mail.log'"
  assert_success
}

#
# postfix
#

@test "postfix: vhost file is correct" {
  _run_in_container cat /etc/postfix/vhost
  assert_success
  assert_line --index 0 "localdomain2.com"
  assert_line --index 1 "localhost.localdomain"
  assert_line --index 2 "otherdomain.tld"
}

#
# postsrsd
#

@test "SRS: main.cf entries" {
  _run_in_container grep "sender_canonical_maps = tcp:localhost:10001" /etc/postfix/main.cf
  assert_success
  _run_in_container grep "sender_canonical_classes = envelope_sender" /etc/postfix/main.cf
  assert_success
  _run_in_container grep "recipient_canonical_maps = tcp:localhost:10002" /etc/postfix/main.cf
  assert_success
  _run_in_container grep "recipient_canonical_classes = envelope_recipient,header_recipient" /etc/postfix/main.cf
  assert_success
}

@test "SRS: fallback to hostname is handled correctly" {
  _run_in_container grep "SRS_DOMAIN=example.test" /etc/default/postsrsd
  assert_success
}

#
# system
#

@test "system: freshclam cron is disabled" {
  _run_in_container_bash "grep '/usr/bin/freshclam' -r /etc/cron.d"
  assert_failure
}

@test "amavis: virusmail wiper cron exists" {
  _run_in_container_bash "crontab -l | grep '/usr/local/bin/virus-wiper'"
  assert_success
}

@test "amavis: VIRUSMAILS_DELETE_DELAY override works as expected" {
  # shellcheck disable=SC2016
  run docker run --rm -e VIRUSMAILS_DELETE_DELAY=2 "${IMAGE_NAME:?}" /bin/bash -c 'echo "${VIRUSMAILS_DELETE_DELAY}"'
  assert_output 2
}

@test "amavis: old virusmail is wipped by cron" {
  # shellcheck disable=SC2016
  _exec_in_container_bash 'touch -d "`date --date=2000-01-01`" /var/lib/amavis/virusmails/should-be-deleted'
  _run_in_container_bash '/usr/local/bin/virus-wiper'
  assert_success
  _run_in_container_bash 'ls -la /var/lib/amavis/virusmails/ | grep should-be-deleted'
  assert_failure
}

@test "amavis: recent virusmail is not wipped by cron" {
  # shellcheck disable=SC2016
  _exec_in_container_bash 'touch -d "`date`"  /var/lib/amavis/virusmails/should-not-be-deleted'
  _run_in_container_bash '/usr/local/bin/virus-wiper'
  assert_success
  _run_in_container_bash 'ls -la /var/lib/amavis/virusmails/ | grep should-not-be-deleted'
  assert_success
}

@test "system: /var/log/mail/mail.log is error free" {
  _run_in_container grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep 'mail system configuration error' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep ': error:' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep -i 'is not writable' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep -i 'permission denied' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep -i '(!)connect' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep -i 'using backwards-compatible default setting' /var/log/mail/mail.log
  assert_failure
  _run_in_container grep -i 'connect to 127.0.0.1:10023: Connection refused' /var/log/mail/mail.log
  assert_failure
}

@test "system: /var/log/auth.log is error free" {
  _run_in_container grep 'Unable to open env file: /etc/default/locale' /var/log/auth.log
  assert_failure
}

@test "system: postfix should not log to syslog" {
  _run_in_container grep 'postfix' /var/log/syslog
  assert_failure
}

@test "system: amavis decoders installed and available" {
  _run_in_container_bash "grep -E '.*(Internal decoder|Found decoder) for\s+\..*' /var/log/mail/mail.log*|grep -Eo '(mail|Z|gz|bz2|xz|lzma|lrz|lzo|lz4|rpm|cpio|tar|deb|rar|arj|arc|zoo|doc|cab|tnef|zip|kmz|7z|jar|swf|lha|iso|exe)' | sort | uniq"
  assert_success
  # Support for doc and zoo removed in buster
  cat <<'EOF' | assert_output
7z
Z
arc
arj
bz2
cab
cpio
deb
exe
gz
iso
jar
kmz
lha
lrz
lz4
lzma
lzo
mail
rar
rpm
swf
tar
tnef
xz
zip
EOF
}

@test "quota: setquota user must be existing" {
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  _run_in_container_bash "setquota quota_user 50M"
  assert_failure
  _run_in_container_bash "setquota quota_user@domain.tld 50M"
  assert_success

  _run_in_container_bash "setquota username@fulldomain 50M"
  assert_failure

  _run_in_container_bash "delmailuser -y quota_user@domain.tld"
  assert_success
}

@test "quota: setquota <quota> must be well formatted" {
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  _run_in_container_bash "setquota quota_user@domain.tld 26GIGOTS"
  assert_failure
  _run_in_container_bash "setquota quota_user@domain.tld 123"
  assert_failure
  _run_in_container_bash "setquota quota_user@domain.tld M"
  assert_failure
  _run_in_container_bash "setquota quota_user@domain.tld -60M"
  assert_failure


  _run_in_container_bash "setquota quota_user@domain.tld 10B"
  assert_success
  _run_in_container_bash "setquota quota_user@domain.tld 10k"
  assert_success
  _run_in_container_bash "setquota quota_user@domain.tld 10M"
  assert_success
  _run_in_container_bash "setquota quota_user@domain.tld 10G"
  assert_success
  _run_in_container_bash "setquota quota_user@domain.tld 10T"
  assert_success


  _run_in_container_bash "delmailuser -y quota_user@domain.tld"
  assert_success
}

@test "quota: delquota user must be existing" {
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  _run_in_container_bash "delquota uota_user@domain.tld"
  assert_failure
  _run_in_container_bash "delquota quota_user"
  assert_failure
  _run_in_container_bash "delquota dontknowyou@domain.tld"
  assert_failure

  _run_in_container_bash "setquota quota_user@domain.tld 10T"
  assert_success
  _run_in_container_bash "delquota quota_user@domain.tld"
  assert_success
  _run_in_container_bash "grep -i 'quota_user@domain.tld' /tmp/docker-mailserver/dovecot-quotas.cf"
  assert_failure

  _run_in_container_bash "delmailuser -y quota_user@domain.tld"
  assert_success
}

@test "quota: delquota allow when no quota for existing user" {
  _add_mail_account_then_wait_until_ready 'quota_user@domain.tld'

  _run_in_container_bash "grep -i 'quota_user@domain.tld' /tmp/docker-mailserver/dovecot-quotas.cf"
  assert_failure

  _run_in_container_bash "delquota quota_user@domain.tld"
  assert_success
  _run_in_container_bash "delquota quota_user@domain.tld"
  assert_success

  _run_in_container_bash "delmailuser -y quota_user@domain.tld"
  assert_success
}

@test "quota: dovecot quota present in postconf" {
  _run_in_container_bash "postconf | grep 'check_policy_service inet:localhost:65265'"
  assert_success
}


@test "quota: dovecot mailbox max size must be equal to postfix mailbox max size" {
  postfix_mailbox_size=$(_exec_in_container_bash "postconf | grep -Po '(?<=mailbox_size_limit = )[0-9]+'")
  run echo "${postfix_mailbox_size}"
  refute_output ""

  # dovecot relies on virtual_mailbox_size by default
  postfix_virtual_mailbox_size=$(_exec_in_container_bash "postconf | grep -Po '(?<=virtual_mailbox_limit = )[0-9]+'")
  assert_equal "${postfix_virtual_mailbox_size}" "${postfix_mailbox_size}"

  postfix_mailbox_size_mb=$(( postfix_mailbox_size / 1000000))

  dovecot_mailbox_size_mb=$(_exec_in_container_bash "doveconf | grep  -oP '(?<=quota_rule \= \*\:storage=)[0-9]+'")
  run echo "${dovecot_mailbox_size_mb}"
  refute_output ""

  assert_equal "${postfix_mailbox_size_mb}" "${dovecot_mailbox_size_mb}"
}


@test "quota: dovecot message max size must be equal to postfix messsage max size" {
  postfix_message_size=$(_exec_in_container_bash "postconf | grep -Po '(?<=message_size_limit = )[0-9]+'")
  run echo "${postfix_message_size}"
  refute_output ""

  postfix_message_size_mb=$(( postfix_message_size / 1000000))

  dovecot_message_size_mb=$(_exec_in_container_bash "doveconf | grep  -oP '(?<=quota_max_mail_size = )[0-9]+'")
  run echo "${dovecot_message_size_mb}"
  refute_output ""

  assert_equal "${postfix_message_size_mb}" "${dovecot_message_size_mb}"
}

@test "quota: quota directive is removed when mailbox is removed" {
  _add_mail_account_then_wait_until_ready 'quserremoved@domain.tld'

  _run_in_container_bash "setquota quserremoved@domain.tld 12M"
  assert_success

  _run_in_container_bash 'cat /tmp/docker-mailserver/dovecot-quotas.cf | grep -E "^quserremoved@domain.tld\:12M\$" | wc -l | grep 1'
  assert_success

  _run_in_container_bash "delmailuser -y quserremoved@domain.tld"
  assert_success

  _run_in_container_bash 'cat /tmp/docker-mailserver/dovecot-quotas.cf | grep -E "^quserremoved@domain.tld\:12M\$"'
  assert_failure
}

@test "quota: dovecot applies user quota" {
  _run_in_container_bash "doveadm quota get -u 'user1@localhost.localdomain' | grep 'User quota STORAGE'"
  assert_output --partial "-                         0"

  _run_in_container_bash "setquota user1@localhost.localdomain 50M"
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'doveadm quota get -u user1@localhost.localdomain | grep -oP "(User quota STORAGE\s+[0-9]+\s+)51200(.*)"'
  assert_success

  _run_in_container_bash "delquota user1@localhost.localdomain"
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'doveadm quota get -u user1@localhost.localdomain | grep -oP "(User quota STORAGE\s+[0-9]+\s+)-(.*)"'
  assert_success
}

@test "quota: warn message received when quota exceeded" {
  skip 'disabled as it fails randomly: https://github.com/docker-mailserver/docker-mailserver/pull/2511'

  # create user
  _add_mail_account_then_wait_until_ready 'quotauser@otherdomain.tld'
  _run_in_container_bash 'setquota quotauser@otherdomain.tld 10k'
  assert_success

  # wait until quota has been updated
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'doveadm quota get -u quotauser@otherdomain.tld | grep -oP \"(User quota STORAGE\s+[0-9]+\s+)10(.*)\"'
  assert_success

  # dovecot and postfix has been restarted
  _wait_for_service postfix
  _wait_for_service dovecot
  sleep 10

  # send some big emails
  _send_email 'email-templates/quota-exceeded' '0.0.0.0 25'
  _send_email 'email-templates/quota-exceeded' '0.0.0.0 25'
  _send_email 'email-templates/quota-exceeded' '0.0.0.0 25'

  # check for quota warn message existence
  run _repeat_until_success_or_timeout 20 _exec_in_container_bash 'grep \"Subject: quota warning\" /var/mail/otherdomain.tld/quotauser/new/ -R'
  assert_success

  run _repeat_until_success_or_timeout 20 sh -c "docker logs mail | grep 'Quota exceeded (mailbox for user is full)'"
  assert_success

  # ensure only the first big message and the warn message are present (other messages are rejected: mailbox is full)
  _run_in_container sh -c 'ls /var/mail/otherdomain.tld/quotauser/new/ | wc -l'
  assert_success
  assert_output "2"

  _run_in_container_bash "delmailuser -y quotauser@otherdomain.tld"
  assert_success
}

#
# PERMIT_DOCKER mynetworks
#

@test "PERMIT_DOCKER: can get container ip" {
  _run_in_container_bash "ip addr show eth0 | grep 'inet ' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1 | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'"
  assert_success
}

@test "PERMIT_DOCKER: my network value" {
  _run_in_container_bash "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.0\.0/16'"
  assert_success
}

#
# amavis
#

@test "amavis: config overrides" {
  _run_in_container_bash "grep 'Test Verification' /etc/amavis/conf.d/50-user | wc -l"
  assert_success
  assert_output 1
}

# TODO investigate why this test fails
@test "user login: predefined user can login" {
  skip 'disabled as it fails randomly: https://github.com/docker-mailserver/docker-mailserver/pull/2177'
  _run_in_container_bash "doveadm auth test -x service=smtp pass@localhost.localdomain 'may be \\a \`p^a.*ssword' | grep 'passdb'"
  assert_output "passdb: pass@localhost.localdomain auth succeeded"
}

#
# LDAP
#

# postfix

@test "dovecot: postmaster address" {
  _run_in_container_bash "grep 'postmaster_address = postmaster@example.test' /etc/dovecot/conf.d/15-lda.conf"
  assert_success
}

@test "spoofing: rejects sender forging" {
  # rejection of spoofed sender
  _wait_for_smtp_port_in_container_to_respond
  _run_in_container_bash "openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/added-smtp-auth-spoofed.txt"
  assert_output --partial 'Sender address rejected: not owned by user'
}

@test "spoofing: accepts sending as alias" {
  _run_in_container_bash "openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/added-smtp-auth-spoofed-alias.txt | grep 'End data with'"
  assert_success
}

#
# Pflogsumm delivery check
#

@test "pflogsum delivery" {
  # logrotation working and report being sent
  _exec_in_container logrotate --force /etc/logrotate.d/maillog
  sleep 10
  _run_in_container grep "Subject: Postfix Summary for " /var/mail/localhost.localdomain/user1/new/ -R
  assert_success
  # check sender is the one specified in REPORT_SENDER
  _run_in_container grep "From: report1@mail.example.test" /var/mail/localhost.localdomain/user1/new/ -R
  assert_success
  # check sender is not the default one.
  _run_in_container grep "From: mailserver-report@mail.example.test" /var/mail/localhost.localdomain/user1/new/ -R
  assert_failure
}
