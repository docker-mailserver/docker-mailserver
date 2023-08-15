load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[LDAP] '
CONTAINER1_NAME='dms-test_ldap'
CONTAINER2_NAME='dms-test_ldap_provider'

function setup_file() {
  export DMS_TEST_NETWORK='test-network-ldap'
  export DOMAIN='example.test'
  export FQDN_MAIL="mail.${DOMAIN}"
  export FQDN_LDAP="ldap.${DOMAIN}"
  # LDAP is provisioned with two domains (via `.ldif` files) unrelated to the FQDN of DMS:
  export FQDN_LOCALHOST_A='localhost.localdomain'
  export FQDN_LOCALHOST_B='localhost.otherdomain'

  # Link the test containers to separate network:
  # NOTE: If the network already exists, test will fail to start.
  docker network create "${DMS_TEST_NETWORK}"

  # Setup local openldap service:
  # NOTE: Building via Dockerfile is required? Image won't accept read-only if it needs to adjust permissions for bootstrap files.
  # TODO: Upstream image is no longer maintained, may want to migrate?
  pushd test/docker-openldap/ || return 1
  docker build -f Dockerfile -t dms-openldap --no-cache .
  popd || return 1

  docker run -d --name "${CONTAINER2_NAME}" \
    --env LDAP_DOMAIN="${FQDN_LOCALHOST_A}" \
    --hostname "${FQDN_LDAP}" \
    --network "${DMS_TEST_NETWORK}" \
    dms-openldap

  local ENV_LDAP_CONFIG=(
    # Configure for LDAP account provisioner and alternative to Dovecot SASL:
    --env ACCOUNT_PROVISIONER=LDAP
    --env ENABLE_SASLAUTHD=1
    --env SASLAUTHD_MECHANISMS=ldap

    # ENV to configure LDAP configs for Dovecot + Postfix:
    # NOTE: `scripts/startup/setup.d/ldap.sh:_setup_ldap()` uses `_replace_by_env_in_file()` to configure settings (stripping `DOVECOT_` / `LDAP_` prefixes):
    # Dovecot:
    --env DOVECOT_PASS_FILTER='(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))'
    --env DOVECOT_TLS=no
    --env DOVECOT_USER_FILTER='(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))'
    # Postfix:
    --env LDAP_BIND_DN='cn=admin,dc=localhost,dc=localdomain'
    --env LDAP_BIND_PW='admin'
    --env LDAP_QUERY_FILTER_ALIAS='(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))'
    --env LDAP_QUERY_FILTER_DOMAIN='(|(&(mail=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailGroupMember=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailalias=*@%s)(objectClass=PostfixBookMailForward)))'
    --env LDAP_QUERY_FILTER_GROUP='(&(mailGroupMember=%s)(mailEnabled=TRUE))'
    --env LDAP_QUERY_FILTER_SENDERS='(|(&(mail=%s)(mailEnabled=TRUE))(&(mailGroupMember=%s)(mailEnabled=TRUE))(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))(uniqueIdentifier=some.user.id))'
    --env LDAP_QUERY_FILTER_USER='(&(mail=%s)(mailEnabled=TRUE))'
    --env LDAP_SEARCH_BASE='ou=people,dc=localhost,dc=localdomain'
    --env LDAP_SERVER_HOST="${FQDN_LDAP}"
    --env LDAP_START_TLS=no
  )

  # Extra ENV needed to support specific testcases:
  local ENV_SUPPORT=(
    --env PERMIT_DOCKER=container # Required for attempting SMTP auth on port 25 via nc
    # Required for openssl commands to be successul:
    # NOTE: snakeoil cert is created (for `docker-mailserver.invalid`) via Debian post-install script for Postfix package.
    # TODO: Use proper TLS cert
    --env SSL_TYPE='snakeoil'

    # TODO; All below are questionable value to LDAP tests?
    --env POSTMASTER_ADDRESS="postmaster@${FQDN_LOCALHOST_A}" # TODO: Only required because LDAP accounts use unrelated domain part. FQDN_LOCALHOST_A / ldif files can be adjusted to FQDN_MAIL
    --env PFLOGSUMM_TRIGGER=logrotate
    --env REPORT_RECIPIENT=1 # TODO: Invalid value, should be a recipient address (if not default postmaster), remove?
    --env SPOOF_PROTECTION=1
  )

  local CUSTOM_SETUP_ARGUMENTS=(
    --hostname "${FQDN_MAIL}"
    --network "${DMS_TEST_NETWORK}"

    "${ENV_LDAP_CONFIG[@]}"
    "${ENV_SUPPORT[@]}"
  )

  # Set default implicit container fallback for helpers:
  export CONTAINER_NAME
  CONTAINER_NAME=${CONTAINER1_NAME}

  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
  docker network rm "${DMS_TEST_NETWORK}"
}

# postfix
# NOTE: Each of the 3 user accounts tested below are defined in separate LDIF config files,
# Those are bundled into the locally built OpenLDAP Dockerfile.
@test "checking postfix: ldap lookup works correctly" {
  _should_exist_in_ldap_tables "some.user@${FQDN_LOCALHOST_A}"

  # Test email receiving from a other domain then the primary domain of the mailserver
  _should_exist_in_ldap_tables "some.other.user@${FQDN_LOCALHOST_B}"

  # Should not require `uniqueIdentifier` to match the local part of `mail` (`.ldif` defined settings):
  # REF: https://github.com/docker-mailserver/docker-mailserver/pull/642#issuecomment-313916384
  # NOTE: This account has no `mailAlias` or `mailGroupMember` defined in it's `.ldif`.
  local MAIL_ACCOUNT="some.user.email@${FQDN_LOCALHOST_A}"
  _run_in_container postmap -q "${MAIL_ACCOUNT}" ldap:/etc/postfix/ldap-users.cf
  assert_success
  assert_output "${MAIL_ACCOUNT}"
}

# Custom LDAP config files support:
# TODO: Compare to provided configs and if they're just including a test comment,
# could just copy the config and append without carrying a separate test config?
@test "checking postfix: ldap custom config files copied" {
  local LDAP_CONFIGS_POSTFIX=(
    /etc/postfix/ldap-users.cf
    /etc/postfix/ldap-groups.cf
    /etc/postfix/ldap-aliases.cf
  )

  for LDAP_CONFIG in "${LDAP_CONFIGS_POSTFIX[@]}"; do
    _run_in_container grep '# Testconfig for ldap integration' "${LDAP_CONFIG}"
    assert_success
  done
}

@test "checking postfix: ldap config overwrites success" {
  local LDAP_SETTINGS_POSTFIX=(
    "server_host = ${FQDN_LDAP}"
    'start_tls = no'
    'search_base = ou=people,dc=localhost,dc=localdomain'
    'bind_dn = cn=admin,dc=localhost,dc=localdomain'
  )

  for LDAP_SETTING in "${LDAP_SETTINGS_POSTFIX[@]}"; do
    # "${LDAP_SETTING%=*}" is to match only the key portion of the var (helpful for assert_output error messages)
    # NOTE: `start_tls = no` is a default setting, but the white-space differs when ENV `LDAP_START_TLS` is not set explicitly.
    _run_in_container grep "${LDAP_SETTING%=*}" /etc/postfix/ldap-users.cf
    assert_output "${LDAP_SETTING}"
    assert_success

    _run_in_container grep "${LDAP_SETTING%=*}" /etc/postfix/ldap-groups.cf
    assert_output "${LDAP_SETTING}"
    assert_success

    _run_in_container grep "${LDAP_SETTING%=*}" /etc/postfix/ldap-aliases.cf
    assert_output "${LDAP_SETTING}"
    assert_success
  done
}

# dovecot
@test "checking dovecot: ldap imap connection and authentication works" {
  _run_in_container_bash 'nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-ldap-auth.txt'
  assert_success
}

@test "checking dovecot: ldap mail delivery works" {
  _run_in_container_bash "sendmail -f user@external.tld some.user@${FQDN_LOCALHOST_A} < /tmp/docker-mailserver-test/email-templates/test-email.txt"
  sleep 10
  _run_in_container grep -R 'This is a test mail.' "/var/mail/${FQDN_LOCALHOST_A}/some.user/new/"
  assert_success
  _should_output_number_of_lines 1
}

@test "checking dovecot: ldap mail delivery works for a different domain then the mailserver" {
  _run_in_container_bash "sendmail -f user@external.tld some.other.user@${FQDN_LOCALHOST_B} < /tmp/docker-mailserver-test/email-templates/test-email.txt"
  sleep 10
  _run_in_container ls -A "/var/mail/${FQDN_LOCALHOST_A}/some.other.user/new"
  assert_success
  _should_output_number_of_lines 1
}

@test "checking dovecot: ldap config overwrites success" {
  local LDAP_SETTINGS_DOVECOT=(
    "uris = ldap://${FQDN_LDAP}"
    'tls = no'
    'base = ou=people,dc=localhost,dc=localdomain'
    'dn = cn=admin,dc=localhost,dc=localdomain'
  )

  for LDAP_SETTING in "${LDAP_SETTINGS_DOVECOT[@]}"; do
    _run_in_container grep "${LDAP_SETTING%=*}" /etc/dovecot/dovecot-ldap.conf.ext
    assert_output "${LDAP_SETTING}"
    assert_success
  done
}

@test "checking dovecot: postmaster address" {
  _run_in_container grep "postmaster_address = postmaster@${FQDN_LOCALHOST_A}" /etc/dovecot/conf.d/15-lda.conf
  assert_success
}

@test "checking dovecot: quota plugin is disabled" {
 _run_in_container grep '\$mail_plugins quota' /etc/dovecot/conf.d/10-mail.conf
 assert_failure
 _run_in_container grep '\$mail_plugins imap_quota' /etc/dovecot/conf.d/20-imap.conf
 assert_failure
 _run_in_container ls /etc/dovecot/conf.d/90-quota.conf
 assert_failure
 _run_in_container ls /etc/dovecot/conf.d/90-quota.conf.disab
 assert_success
}

@test "checking postfix: dovecot quota absent in postconf" {
  _run_in_container postconf
  refute_output --partial 'check_policy_service inet:localhost:65265'
}

@test "checking spoofing (with LDAP): rejects sender forging" {
  _wait_for_smtp_port_in_container_to_respond dms-test_ldap

  _run_in_container_bash 'openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed.txt'
  assert_output --partial 'Sender address rejected: not owned by user'
}

# ATTENTION: these tests must come after "checking dovecot: ldap mail delivery works" since they will deliver an email which skews the count in said test, leading to failure
@test "checking spoofing: accepts sending as alias (with LDAP)" {
  _run_in_container_bash 'openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed-alias.txt'
  assert_output --partial 'End data with'
}
@test "checking spoofing: uses senders filter" {
  # skip introduced with #3006, changing port 25 to 465
  skip 'TODO: This test seems to have been broken from the start (?)'

  _run_in_container_bash 'openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed-sender-with-filter-exception.txt'
  assert_output --partial 'Sender address rejected: not owned by user'
}

# saslauthd
@test "checking saslauthd: sasl ldap authentication works" {
  _run_in_container testsaslauthd -u some.user -p secret
  assert_success
}

@test "checking saslauthd: ldap smtp authentication" {
  _run_in_container_bash 'nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt'
  assert_output --partial 'Error: authentication not enabled'

  _run_in_container_bash 'openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt'
  assert_output --partial 'Authentication successful'

  _run_in_container_bash 'openssl s_client -quiet -starttls smtp -connect 0.0.0.0:587 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt'
  assert_output --partial 'Authentication successful'
}

#
# Pflogsumm delivery check
#

@test "checking pflogsum delivery" {
  # checking default sender is correctly set when env variable not defined
  _run_in_container grep "mailserver-report@${FQDN_MAIL}" /etc/logrotate.d/maillog
  assert_success

  # checking default logrotation setup
  _run_in_container grep 'weekly' /etc/logrotate.d/maillog
  assert_success
}

# Test helper methods:

function _should_exist_in_ldap_tables() {
  local MAIL_ACCOUNT=${1:?Mail account is required}
  local DOMAIN_PART="${MAIL_ACCOUNT#*@}"

  # Each LDAP config file sets `query_filter` to lookup a key in LDAP (values defined in `.ldif` test files)
  # `mail` (ldap-users), `mailAlias` (ldap-aliases), `mailGroupMember` (ldap-groups)
  # `postmap` is queried with the mail account address, and the LDAP service should respond with
  # `result_attribute` which is the LDAP `mail` value (should match what we'r'e quering `postmap` with)

  _run_in_container postmap -q "${MAIL_ACCOUNT}" ldap:/etc/postfix/ldap-users.cf
  assert_success
  assert_output "${MAIL_ACCOUNT}"

  # Check which account has the `postmaster` virtual alias:
  _run_in_container postmap -q "postmaster@${DOMAIN_PART}" ldap:/etc/postfix/ldap-aliases.cf
  assert_success
  assert_output "${MAIL_ACCOUNT}"

  _run_in_container postmap -q "employees@${DOMAIN_PART}" ldap:/etc/postfix/ldap-groups.cf
  assert_success
  assert_output "${MAIL_ACCOUNT}"
}
