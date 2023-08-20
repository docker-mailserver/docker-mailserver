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
  docker run --rm -d --name "${CONTAINER2_NAME}" \
    --env LDAP_ADMIN_PASSWORD=admin \
    --env LDAP_ROOT='dc=localhost,dc=localdomain' \
    --env LDAP_PORT_NUMBER=389 \
    --env LDAP_SKIP_DEFAULT_TREE=yes \
    --volume './test/config/ldap/docker-openldap/bootstrap/ldif/:/ldifs/:ro' \
    --volume './test/config/ldap/docker-openldap/bootstrap/schemas/:/schemas/:ro' \
    --hostname "${FQDN_LDAP}" \
    --network "${DMS_TEST_NETWORK}" \
    bitnami/openldap:latest

  _run_until_success_or_timeout 20 sh -c "docker logs ${CONTAINER2_NAME} 2>&1 | grep 'LDAP setup finished'"

  #
  # Setup DMS container
  #

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
  export CONTAINER_NAME=${CONTAINER1_NAME}

  _init_with_defaults
  # NOTE: `test/config/` has now been duplicated, can move test specific files to host-side `/tmp/docker-mailserver`:
  mv "${TEST_TMP_CONFIG}/ldap/overrides/"*.cf "${TEST_TMP_CONFIG}/"
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
@test "postfix: ldap lookup works correctly" {
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
@test "postfix: ldap custom config files copied" {
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

@test "postfix: ldap config overwrites success" {
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
@test "dovecot: ldap imap connection and authentication works" {
  _run_in_container_bash 'nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-ldap-auth.txt'
  assert_success
}

@test "dovecot: ldap mail delivery works" {
  _should_successfully_deliver_mail_to "some.user@${FQDN_LOCALHOST_A}" "/var/mail/${FQDN_LOCALHOST_A}/some.user/new/"

  # Should support delivering to a local recipient with a different domain (and disjoint mail location):
  # NOTE: Mail is delivered to location defined in `.ldif` (an account config setting, either `mailHomeDirectory` or `mailStorageDirectory`).
  # `some.other.user` has been configured to use a mailbox domain different from it's address domain part, hence the difference here:
  _should_successfully_deliver_mail_to "some.other.user@${FQDN_LOCALHOST_B}" "/var/mail/${FQDN_LOCALHOST_A}/some.other.user/new/"
}

@test "dovecot: ldap config overwrites success" {
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

# Requires ENV `POSTMASTER_ADDRESS`
# NOTE: Not important to LDAP feature tests?
@test "dovecot: postmaster address" {
  _run_in_container grep "postmaster_address = postmaster@${FQDN_LOCALHOST_A}" /etc/dovecot/conf.d/15-lda.conf
  assert_success
}

# NOTE: `target/scripts/startup/setup.d/dovecot.sh` should prevent enabling the quotas feature when using LDAP:
@test "dovecot: quota plugin is disabled" {
  # Dovecot configs have not enabled the quota plugins:
  _run_in_container grep "\$mail_plugins quota" /etc/dovecot/conf.d/10-mail.conf
  assert_failure
  _run_in_container grep "\$mail_plugins imap_quota" /etc/dovecot/conf.d/20-imap.conf
  assert_failure

  # Dovecot Quota config only present with disabled extension:
  _run_in_container_bash '[[ -f /etc/dovecot/conf.d/90-quota.conf ]]'
  assert_failure
  _run_in_container_bash '[[ -f /etc/dovecot/conf.d/90-quota.conf.disab ]]'
  assert_success

  # Postfix quotas policy service not configured in `main.cf`:
  _run_in_container postconf smtpd_recipient_restrictions
  refute_output --partial 'check_policy_service inet:localhost:65265'
}

@test "saslauthd: sasl ldap authentication works" {
  _run_in_container testsaslauthd -u some.user -p secret
  assert_success
}

# Requires ENV `PFLOGSUMM_TRIGGER=logrotate`
@test "pflogsumm delivery" {
  # Verify default sender is `mailserver-report` when ENV `PFLOGSUMM_SENDER` + `REPORT_SENDER` are unset:
  # NOTE: Mail is sent from Postfix (configured hostname used as domain part)
  _run_in_container grep "mailserver-report@${FQDN_MAIL}" /etc/logrotate.d/maillog
  assert_success

  # When `LOGROTATE_INTERVAL` is unset, the default should be configured as `weekly`:
  _run_in_container grep 'weekly' /etc/logrotate.d/maillog
  assert_success
}

# ATTENTION: Remaining tests must come after "dovecot: ldap mail delivery works" since the below tests would affect the expected count (by delivering extra mail),
# Thus not friendly for running testcases in this file in parallel

# Requires ENV `SPOOF_PROTECTION=1` for the expected assert_output
@test "spoofing (with LDAP): rejects sender forging" {
  _wait_for_smtp_port_in_container_to_respond dms-test_ldap

  _run_in_container_bash 'openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed.txt'
  assert_output --partial 'Sender address rejected: not owned by user'
}

@test "spoofing (with LDAP): accepts sending as alias" {
  _run_in_container_bash 'openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed-alias.txt'
  assert_output --partial 'End data with'
}

@test "spoofing (with LDAP): uses senders filter" {
  # skip introduced with #3006, changing port 25 to 465
  # Template used has invalid AUTH: https://github.com/docker-mailserver/docker-mailserver/pull/3006#discussion_r1073321432
  skip 'TODO: This test seems to have been broken from the start (?)'

  _run_in_container_bash 'openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed-sender-with-filter-exception.txt'
  assert_output --partial 'Sender address rejected: not owned by user'
}

@test "saslauthd: ldap smtp authentication" {
  # Requires ENV `PERMIT_DOCKER=container`
  _send_email 'auth/sasl-ldap-smtp-auth' '-w 5 0.0.0.0 25'
  assert_output --partial 'Error: authentication not enabled'

  _run_in_container_bash 'openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt'
  assert_output --partial 'Authentication successful'

  _run_in_container_bash 'openssl s_client -quiet -starttls smtp -connect 0.0.0.0:587 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt'
  assert_output --partial 'Authentication successful'
}

#
# Test helper methods:
#

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

# NOTE: `test-email.txt` is only used for these two LDAP tests with `sendmail` command.
# The file excludes sender/recipient addresses, thus not usable with `_send_email()` helper (`nc` command)?
# TODO: Could probably adapt?
function _should_successfully_deliver_mail_to() {
  local SENDER_ADDRESS='user@external.tld'
  local RECIPIENT_ADDRESS=${1:?Recipient address is required}
  local MAIL_STORAGE_RECIPIENT=${2:?Recipient storage location is required}
  local MAIL_TEMPLATE='/tmp/docker-mailserver-test/email-templates/test-email.txt'

  _run_in_container_bash "sendmail -f ${SENDER_ADDRESS} ${RECIPIENT_ADDRESS} < ${MAIL_TEMPLATE}"
  _wait_for_empty_mail_queue_in_container

  _run_in_container grep -R 'This is a test mail.' "${MAIL_STORAGE_RECIPIENT}"
  assert_success
  _should_output_number_of_lines 1

  # NOTE: Prevents compatibility for running testcases in parallel (for same container) when the count could become racey:
  _count_files_in_directory_in_container "${MAIL_STORAGE_RECIPIENT}" 1
}
