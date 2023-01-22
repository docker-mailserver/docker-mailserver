load "${REPOSITORY_ROOT}/test/test_helper/common"

CONTAINER1_NAME='mail_override_hostname'
CONTAINER2_NAME='mail_non_subdomain_hostname'
CONTAINER3_NAME='mail_srs_domainname'
CONTAINER4_NAME='mail_domainname'

function setup_file() {
  local PRIVATE_CONFIG

  # mail_override_hostname
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER1_NAME}")
  docker run --rm -d --name "${CONTAINER1_NAME}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    --env PERMIT_DOCKER='container' \
    --env ENABLE_SRS=1 \
    --env OVERRIDE_HOSTNAME='mail.my-domain.com' \
    --hostname 'unknown.domain.tld' \
    --tty \
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)" \
    "${NAME}"

  # mail_non_subdomain_hostname
  PRIVATE_CONFIG_TWO=$(duplicate_config_for_container . "${CONTAINER2_NAME}")
  docker run --rm -d --name "${CONTAINER2_NAME}" \
    -v "${PRIVATE_CONFIG_TWO}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    --env PERMIT_DOCKER='container' \
    --env ENABLE_SRS=1 \
    --hostname 'domain.com' \
    --tty \
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)" \
    "${NAME}"

  # mail_srs_domainname
  PRIVATE_CONFIG_THREE=$(duplicate_config_for_container . "${CONTAINER3_NAME}")
  docker run --rm -d --name "${CONTAINER3_NAME}" \
    -v "${PRIVATE_CONFIG_THREE}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    --env PERMIT_DOCKER='container' \
    --env ENABLE_SRS=1 \
    --env SRS_DOMAINNAME='srs.my-domain.com' \
    --domainname 'my-domain.com' \
    --hostname 'mail' \
    --tty \
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)" \
    "${NAME}"

  # mail_domainname
  PRIVATE_CONFIG_FOUR=$(duplicate_config_for_container . "${CONTAINER4_NAME}")
  docker run --rm -d --name "${CONTAINER4_NAME}" \
    -v "${PRIVATE_CONFIG_FOUR}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    --env PERMIT_DOCKER='container' \
    --env ENABLE_SRS=1 \
    --domainname 'my-domain.com' \
    --hostname 'mail' \
    --tty \
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)" \
    "${NAME}"

  wait_for_smtp_port_in_container "${CONTAINER1_NAME}"
  wait_for_smtp_port_in_container "${CONTAINER2_NAME}"
  wait_for_smtp_port_in_container "${CONTAINER3_NAME}"
  wait_for_smtp_port_in_container "${CONTAINER4_NAME}"
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}" "${CONTAINER3_NAME}" "${CONTAINER4_NAME}"
}

@test "checking SRS: SRS_DOMAINNAME is used correctly" {
  local CONTAINER_NAME="${CONTAINER3_NAME}"

  # PostSRSd should be configured correctly:
  run docker exec "${CONTAINER_NAME}" grep '^SRS_DOMAIN=' /etc/default/postsrsd
  assert_output "SRS_DOMAIN=srs.my-domain.com"
  assert_success
}

@test "checking SRS: DOMAINNAME is handled correctly" {
  local CONTAINER_NAME="${CONTAINER4_NAME}"

  # PostSRSd should be configured correctly:
  run docker exec "${CONTAINER_NAME}" grep '^SRS_DOMAIN=' /etc/default/postsrsd
  assert_output "SRS_DOMAIN=my-domain.com"
  assert_success
}

@test "checking configuration: hostname/domainname override: check overriden hostname is applied to all configs" {
  local CONTAINER_NAME="${CONTAINER1_NAME}"

  # Should be the original `--hostname`, not `OVERRIDE_HOSTNAME`:
  _should_have_expected_hostname 'unknown.domain.tld'

  _should_be_configured_to_domainname 'my-domain.com'
  _should_be_configured_to_fqdn 'mail.my-domain.com'

  _should_have_correct_mail_headers 'mail.my-domain.com' 'unknown.domain.tld'
  # Container hostname should not be found in received mail (due to `OVERRIDE_HOSTNAME`):
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "grep -R unknown.domain.tld /var/mail/localhost.localdomain/user1/new/"
  assert_failure
}

@test "checking configuration: non-subdomain: check overriden hostname is applied to all configs" {
  local CONTAINER_NAME="${CONTAINER2_NAME}"

  _should_have_expected_hostname 'domain.com'

  _should_be_configured_to_domainname 'domain.com'
  # Bare domain configured, thus no subdomain:
  _should_be_configured_to_fqdn 'domain.com'

  _should_have_correct_mail_headers 'domain.com'
}

function _should_have_expected_hostname() {
  local EXPECTED_FQDN=${1}

  run docker exec "${CONTAINER_NAME}" /bin/bash -c "hostname"
  assert_output "${EXPECTED_FQDN}"
  assert_success

  run docker exec "${CONTAINER_NAME}" /bin/bash -c "grep -E '[[:space:]]+${EXPECTED_FQDN}' /etc/hosts"
  assert_success
}

function _should_be_configured_to_domainname() {
  local EXPECTED_DOMAIN=${1}

  run docker exec "${CONTAINER_NAME}" /bin/bash -c "cat /etc/mailname"
  assert_output "${EXPECTED_DOMAIN}"
  assert_success

  run docker exec "${CONTAINER_NAME}" /bin/bash -c "postconf mydomain"
  assert_output "mydomain = ${EXPECTED_DOMAIN}"
  assert_success

  # PostSRSd should be configured correctly:
  run docker exec "${CONTAINER_NAME}" grep '^SRS_DOMAIN=' /etc/default/postsrsd
  assert_output "SRS_DOMAIN=${EXPECTED_DOMAIN}"
  assert_success

  # Dovecot postmaster address should be configured correctly:
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "grep '^postmaster_address' /etc/dovecot/conf.d/15-lda.conf"
  assert_output "postmaster_address = postmaster@${EXPECTED_DOMAIN}"
  assert_success
}

function _should_be_configured_to_fqdn() {
  local EXPECTED_FQDN=${1}

  # Postfix
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "postconf myhostname"
  assert_output "myhostname = ${EXPECTED_FQDN}"
  assert_success
  # Postfix HELO message should contain FQDN (hostname)
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "nc -w 1 0.0.0.0 25"
  assert_output --partial "220 ${EXPECTED_FQDN} ESMTP"
  assert_success

  # Dovecot
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "doveconf hostname"
  assert_output "hostname = ${EXPECTED_FQDN}"
  assert_success

  # OpenDMARC
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "grep '^AuthservID' /etc/opendmarc.conf"
  assert_output --partial " ${EXPECTED_FQDN}"
  assert_success
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "grep '^TrustedAuthservIDs' /etc/opendmarc.conf"
  assert_output --partial " ${EXPECTED_FQDN}"
  assert_success

  # Amavis
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "grep '^\$myhostname' /etc/amavis/conf.d/05-node_id"
  assert_output "\$myhostname = \"${EXPECTED_FQDN}\";"
  assert_success
}

function _should_have_correct_mail_headers() {
  local EXPECTED_FQDN=${1}
  local EXPECTED_HOSTNAME=${2:-${EXPECTED_FQDN}}

  run docker exec "${CONTAINER_NAME}" /bin/bash -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success

  # Add slight delay to wait for mail delivery (otherwise directory doesn't exist):
  sleep 0.1

  # MTA hostname (sender?) is used in filename of stored mail:
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "ls -A /var/mail/localhost.localdomain/user1/new"
  assert_output --partial ".${EXPECTED_HOSTNAME},"
  # TODO: Also verify only a single mail exists
  assert_success

  # FQDN should be in mail headers:
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "grep -R '${EXPECTED_FQDN}' /var/mail/localhost.localdomain/user1/new/"
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
