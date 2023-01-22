load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Network - Hostname] '
CONTAINER1_NAME='dms-test_hostname_env-override-hostname'
CONTAINER2_NAME='dms-test_hostname_bare-domain'
CONTAINER3_NAME='dms-test_hostname_env-srs-domainname'
CONTAINER4_NAME='dms-test_hostname_fqdn-with-subdomain'

# NOTE: Required until postsrsd package updated:
# `--ulimit` is a workaround for some environments when using ENABLE_SRS=1:
# PR 2730: https://github.com/docker-mailserver/docker-mailserver/commit/672e9cf19a3bb1da309e8cea6ee728e58f905366

function setup_file() {
  export CONTAINER_NAME

  # mail_override_hostname
  CONTAINER_NAME=${CONTAINER1_NAME}
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

  # mail_non_subdomain_hostname
  CONTAINER_NAME=${CONTAINER2_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --hostname 'bare-domain.test'
    --env ENABLE_AMAVIS=1
    --env ENABLE_SRS=1
    --env PERMIT_DOCKER='container'
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # mail_srs_domainname
  CONTAINER_NAME=${CONTAINER3_NAME}
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

  # mail_domainname
  CONTAINER_NAME=${CONTAINER4_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --hostname 'mail'
    --domainname 'example.test'
    --env ENABLE_SRS=1
    --env PERMIT_DOCKER='container'
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _wait_for_smtp_port_in_container "${CONTAINER1_NAME}"
  _wait_for_smtp_port_in_container "${CONTAINER2_NAME}"
  _wait_for_smtp_port_in_container "${CONTAINER3_NAME}"
  _wait_for_smtp_port_in_container "${CONTAINER4_NAME}"
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}" "${CONTAINER3_NAME}" "${CONTAINER4_NAME}"
}

@test "checking SRS: SRS_DOMAINNAME is used correctly" {
  local CONTAINER_NAME="${CONTAINER3_NAME}"

  # PostSRSd should be configured correctly:
  _run_in_container_bash "grep '^SRS_DOMAIN=' /etc/default/postsrsd"
  assert_output "SRS_DOMAIN=srs.example.test"
  assert_success
}

@test "checking SRS: DOMAINNAME is handled correctly" {
  local CONTAINER_NAME="${CONTAINER4_NAME}"

  # PostSRSd should be configured correctly:
  _run_in_container_bash "grep '^SRS_DOMAIN=' /etc/default/postsrsd"
  assert_output "SRS_DOMAIN=example.test"
  assert_success
}

@test "checking configuration: hostname/domainname override: check overriden hostname is applied to all configs" {
  local CONTAINER_NAME="${CONTAINER1_NAME}"

  # Should be the original `--hostname`, not `OVERRIDE_HOSTNAME`:
  _should_have_expected_hostname 'original.example.test'

  _should_be_configured_to_domainname 'override.test'
  _should_be_configured_to_fqdn 'mail.override.test'

  _should_have_correct_mail_headers 'mail.override.test' 'original.example.test'
  # Container hostname should not be found in received mail (due to `OVERRIDE_HOSTNAME`):
  _run_in_container_bash "grep -R original.example.test /var/mail/localhost.localdomain/user1/new/"
  assert_failure
}

@test "checking configuration: non-subdomain: check overriden hostname is applied to all configs" {
  local CONTAINER_NAME="${CONTAINER2_NAME}"

  _should_have_expected_hostname 'bare-domain.test'

  _should_be_configured_to_domainname 'bare-domain.test'
  # Bare domain configured, thus no subdomain:
  _should_be_configured_to_fqdn 'bare-domain.test'

  _should_have_correct_mail_headers 'bare-domain.test'
}

function _should_have_expected_hostname() {
  local EXPECTED_FQDN=${1}

  _run_in_container_bash "hostname"
  assert_output "${EXPECTED_FQDN}"
  assert_success

  _run_in_container_bash "grep -E '[[:space:]]+${EXPECTED_FQDN}' /etc/hosts"
  assert_success
}

function _should_be_configured_to_domainname() {
  local EXPECTED_DOMAIN=${1}

  # setup-stack.sh:_setup_mailname
  _run_in_container_bash "cat /etc/mailname"
  assert_output "${EXPECTED_DOMAIN}"
  assert_success

  # Postfix
  _run_in_container_bash "postconf mydomain"
  assert_output "mydomain = ${EXPECTED_DOMAIN}"
  assert_success

  # PostSRSd
  _run_in_container_bash "grep '^SRS_DOMAIN=' /etc/default/postsrsd"
  assert_output "SRS_DOMAIN=${EXPECTED_DOMAIN}"
  assert_success

  # Dovecot
  _run_in_container_bash "grep '^postmaster_address' /etc/dovecot/conf.d/15-lda.conf"
  assert_output "postmaster_address = postmaster@${EXPECTED_DOMAIN}"
  assert_success
}

function _should_be_configured_to_fqdn() {
  local EXPECTED_FQDN=${1}

  # Postfix
  _run_in_container_bash "postconf myhostname"
  assert_output "myhostname = ${EXPECTED_FQDN}"
  assert_success
  # Postfix HELO message should contain FQDN (hostname)
  _run_in_container_bash "nc -w 1 0.0.0.0 25"
  assert_output --partial "220 ${EXPECTED_FQDN} ESMTP"
  assert_success

  # Dovecot
  _run_in_container_bash "doveconf hostname"
  assert_output "hostname = ${EXPECTED_FQDN}"
  assert_success

  # OpenDMARC
  _run_in_container_bash "grep '^AuthservID' /etc/opendmarc.conf"
  assert_output --partial " ${EXPECTED_FQDN}"
  assert_success
  _run_in_container_bash "grep '^TrustedAuthservIDs' /etc/opendmarc.conf"
  assert_output --partial " ${EXPECTED_FQDN}"
  assert_success

  # Amavis
  _run_in_container_bash "grep '^\$myhostname' /etc/amavis/conf.d/05-node_id"
  assert_output "\$myhostname = \"${EXPECTED_FQDN}\";"
  assert_success
}

function _should_have_correct_mail_headers() {
  local EXPECTED_FQDN=${1}
  local EXPECTED_HOSTNAME=${2:-${EXPECTED_FQDN}}

  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success

  _wait_for_empty_mail_queue_in_container
  _count_files_in_directory_in_container '/var/mail/localhost.localdomain/user1/new/' '1'

  # MTA hostname (sender?) is used in filename of stored mail:
  _run_in_container_bash "ls -A /var/mail/localhost.localdomain/user1/new"
  assert_output --partial ".${EXPECTED_HOSTNAME},"
  assert_success

  # FQDN should be in mail headers:
  _run_in_container_bash "grep -R '${EXPECTED_FQDN}' /var/mail/localhost.localdomain/user1/new/"
  assert_output --partial "Received: from ${EXPECTED_FQDN}"
  assert_output --partial "by ${EXPECTED_FQDN} with LMTP"
  assert_output --partial "by ${EXPECTED_FQDN} (Postfix) with ESMTP id"
  assert_output --partial "@${EXPECTED_FQDN}>"
  # Lines matching partial `@${EXPECTED_FQDN}`:
  # Return-Path: <SRS0=3y+C=5T=external.tld=user@domain.com>
  # (envelope-from <SRS0=3y+C=5T=external.tld=user@domain.com>)
  # Message-Id: <20230122005631.0E2B741FBE18@domain.com>
  assert_success
}
