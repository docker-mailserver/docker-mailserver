load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Network - Hostname] '
CONTAINER1_NAME='dms-test_hostname_fqdn-with-subdomain'
CONTAINER2_NAME='dms-test_hostname_bare-domain'
CONTAINER3_NAME='dms-test_hostname_env-override-hostname'
CONTAINER4_NAME='dms-test_hostname_with-nis-domain'
CONTAINER5_NAME='dms-test_hostname_env-srs-domainname'

# NOTE: Required until postsrsd package updated:
# `--ulimit` is a workaround for some environments when using ENABLE_SRS=1:
# PR 2730: https://github.com/docker-mailserver/docker-mailserver/commit/672e9cf19a3bb1da309e8cea6ee728e58f905366

function teardown() { _default_teardown ; }

@test "should update configuration correctly (Standard FQDN setup)" {
  export CONTAINER_NAME="${CONTAINER1_NAME}"

  # Should be using the default `--hostname mail.example.test`
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_SRS=1
    --env PERMIT_DOCKER='container'
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  _should_have_expected_hostname 'mail.example.test'

  _should_be_configured_to_domainname 'example.test'
  _should_be_configured_to_fqdn 'mail.example.test'

  _should_have_correct_mail_headers 'mail.example.test' 'example.test'
}

@test "should update configuration correctly (Bare Domain)" {
  export CONTAINER_NAME="${CONTAINER2_NAME}"

  local CUSTOM_SETUP_ARGUMENTS=(
    --hostname 'bare-domain.test'
    --env ENABLE_AMAVIS=1
    --env ENABLE_SRS=1
    --env PERMIT_DOCKER='container'
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  _should_have_expected_hostname 'bare-domain.test'

  _should_be_configured_to_domainname 'bare-domain.test'
  # Bare domain configured, thus no subdomain:
  _should_be_configured_to_fqdn 'bare-domain.test'

  _should_have_correct_mail_headers 'bare-domain.test'
}

@test "should update configuration correctly (ENV OVERRIDE_HOSTNAME)" {
  export CONTAINER_NAME="${CONTAINER3_NAME}"

  local CUSTOM_SETUP_ARGUMENTS=(
    --hostname 'original.example.test'
    --env OVERRIDE_HOSTNAME='mail.override.test'
    --env ENABLE_AMAVIS=1
    --env ENABLE_SRS=1
    --env PERMIT_DOCKER='container'
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  # Should be the original `--hostname` (`hostname -f`), not `OVERRIDE_HOSTNAME`:
  _should_have_expected_hostname 'original.example.test'

  _should_be_configured_to_domainname 'override.test'
  _should_be_configured_to_fqdn 'mail.override.test'

  _should_have_correct_mail_headers 'mail.override.test' 'override.test' 'original.example.test'
  # Container hostname should not be found in received mail (due to `OVERRIDE_HOSTNAME`):
  _run_in_container grep -R 'original.example.test' /var/mail/localhost.localdomain/user1/new/
  assert_failure
}

@test "should update configuration correctly (--hostname + --domainname)" {
  export CONTAINER_NAME="${CONTAINER4_NAME}"

  local CUSTOM_SETUP_ARGUMENTS=(
    --hostname 'mail'
    --domainname 'example.test'
    --env ENABLE_AMAVIS=1
    --env ENABLE_SRS=1
    --env PERMIT_DOCKER='container'
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  # Differs from the first test case, matches exact `--hostname` value:
  _should_have_expected_hostname 'mail'

  _should_be_configured_to_domainname 'example.test'
  _should_be_configured_to_fqdn 'mail.example.test'

  # Likewise `--hostname` value will always match the third parameter:
  _should_have_correct_mail_headers 'mail.example.test' 'example.test' 'mail'
}

# This test is purely for testing the ENV `SRS_DOMAINNAME` (not relevant to these tests?)
@test "should give priority to ENV in postsrsd config (ENV SRS_DOMAINNAME)" {
  export CONTAINER_NAME="${CONTAINER5_NAME}"

  local CUSTOM_SETUP_ARGUMENTS=(
    --hostname 'mail'
    --domainname 'example.test'
    --env ENABLE_SRS=1
    --env SRS_DOMAINNAME='srs.example.test'
    --env PERMIT_DOCKER='container'
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # PostSRSd should be configured correctly:
  _run_in_container grep '^SRS_DOMAIN=' /etc/default/postsrsd
  assert_output "SRS_DOMAIN=srs.example.test"
  assert_success
}

function _should_have_expected_hostname() {
  local EXPECTED_FQDN=${1}

  _run_in_container "hostname"
  assert_output "${EXPECTED_FQDN}"
  assert_success

  _run_in_container grep -E "[[:space:]]+${EXPECTED_FQDN}" /etc/hosts
  assert_success
}

function _should_be_configured_to_domainname() {
  local EXPECTED_DOMAIN=${1}

  # setup-stack.sh:_setup_mailname
  _run_in_container cat /etc/mailname
  assert_output "${EXPECTED_DOMAIN}"
  assert_success

  # Postfix
  _run_in_container postconf mydomain
  assert_output "mydomain = ${EXPECTED_DOMAIN}"
  assert_success

  # PostSRSd
  _run_in_container grep '^SRS_DOMAIN=' /etc/default/postsrsd
  assert_output "SRS_DOMAIN=${EXPECTED_DOMAIN}"
  assert_success

  # Dovecot
  _run_in_container grep '^postmaster_address' /etc/dovecot/conf.d/15-lda.conf
  assert_output "postmaster_address = postmaster@${EXPECTED_DOMAIN}"
  assert_success
}

function _should_be_configured_to_fqdn() {
  local EXPECTED_FQDN=${1}

  # Postfix
  _run_in_container postconf myhostname
  assert_output "myhostname = ${EXPECTED_FQDN}"
  assert_success
  # Postfix HELO message should contain FQDN (hostname)
  _run_in_container nc -w 1 0.0.0.0 25
  assert_output --partial "220 ${EXPECTED_FQDN} ESMTP"
  assert_success

  # Dovecot
  _run_in_container doveconf hostname
  assert_output "hostname = ${EXPECTED_FQDN}"
  assert_success

  # OpenDMARC
  _run_in_container grep '^AuthservID' /etc/opendmarc.conf
  assert_output --partial " ${EXPECTED_FQDN}"
  assert_success
  _run_in_container grep '^TrustedAuthservIDs' /etc/opendmarc.conf
  assert_output --partial " ${EXPECTED_FQDN}"
  assert_success

  # Amavis
  # shellcheck disable=SC2016
  _run_in_container grep '^\$myhostname' /etc/amavis/conf.d/05-node_id
  assert_output "\$myhostname = \"${EXPECTED_FQDN}\";"
  assert_success
}

function _should_have_correct_mail_headers() {
  local EXPECTED_FQDN=${1}
  # NOTE: The next two params should not differ for bare domains:
  local EXPECTED_DOMAINPART=${2:-${EXPECTED_FQDN}}
  # Required when EXPECTED_FQDN would not match the container hostname:
  # (eg: OVERRIDE_HOSTNAME or `--hostname mail --domainname example.test`)
  local EXPECTED_HOSTNAME=${3:-${EXPECTED_FQDN}}

  _send_email 'email-templates/existing-user1'
  _wait_for_empty_mail_queue_in_container
  _count_files_in_directory_in_container '/var/mail/localhost.localdomain/user1/new/' '1'

  # MTA hostname (sender?) is used in filename of stored mail:
  local MAIL_FILEPATH=$(_exec_in_container find /var/mail/localhost.localdomain/user1/new -maxdepth 1 -type f)

  run echo "${MAIL_FILEPATH}"
  assert_success
  assert_output --partial ".${EXPECTED_HOSTNAME},"

  # Mail headers should contain EXPECTED_FQDN for lines Received + by + Message-Id
  # For `ENABLE_SRS=1`, EXPECTED_DOMAINPART should match lines Return-Path + envelope-from
  _run_in_container cat "${MAIL_FILEPATH}"
  assert_success
  assert_line --index 0 --partial 'Return-Path: <SRS0='
  assert_line --index 0 --partial "@${EXPECTED_DOMAINPART}>"
  # Passed on from Postfix to Dovecot via LMTP:
  assert_line --index 2 --partial "Received: from ${EXPECTED_FQDN}"
  assert_line --index 3 --partial "by ${EXPECTED_FQDN} with LMTP"
  assert_line --index 5 --partial '(envelope-from <SRS0='
  assert_line --index 5 --partial "@${EXPECTED_DOMAINPART}>"
  # Arrived via Postfix:
  # NOTE: The first `localhost` in this line would actually be `mail.external.tld`,
  # but Amavis is changing that. It also changes protocol from SMTP to ESMTP.
  assert_line --index 7 --partial 'Received: from localhost (localhost [127.0.0.1])'
  assert_line --index 8 --partial "by ${EXPECTED_FQDN} (Postfix) with ESMTP id"
  assert_line --index 14 --partial 'Message-Id:'
  assert_line --index 14 --partial "@${EXPECTED_FQDN}>"

  # Mail contents example:
  #
  # Return-Path: <SRS0=Smtf=5T=external.tld=user@example.test>
  # Delivered-To: user1@localhost.localdomain
  # Received: from mail.example.test
  #   by mail.example.test with LMTP
  #   id jvJfJk23zGPeBgAAUi6ngw
  #   (envelope-from <SRS0=Smtf=5T=external.tld=user@example.test>)
  #   for <user1@localhost.localdomain>; Sun, 22 Jan 2023 04:10:53 +0000
  # Received: from localhost (localhost [127.0.0.1])
  #   by mail.example.test (Postfix) with ESMTP id 8CFC4C30F9C4
  #   for <user1@localhost.localdomain>; Sun, 22 Jan 2023 04:10:53 +0000 (UTC)
  # From: Docker Mail Server <dockermailserver@external.tld>
  # To: Existing Local User <user1@localhost.localdomain>
  # Date: Sat, 22 May 2010 07:43:25 -0400
  # Subject: Test Message existing-user1.txt
  # Message-Id: <20230122041053.5A5F1C2F608E@mail.example.test>
  #
  # This is a test mail.
}
