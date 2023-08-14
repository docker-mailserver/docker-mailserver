load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[LDAP] '
CONTAINER1_NAME='dms-test_ldap'
CONTAINER2_NAME='dms-test_ldap_provider'

function setup_file() {
  pushd test/docker-openldap/ || return 1
  docker build -f Dockerfile -t dms-openldap --no-cache .
  popd || return 1

  export DOMAIN='example.test'
  export FQDN_MAIL="mail.${DOMAIN}"
  export FQDN_LDAP="ldap.${DOMAIN}"
  export FQDN_LOCALHOST_A='localhost.localdomain'
  export FQDN_LOCALHOST_B='localhost.otherdomain'
  export DMS_TEST_NETWORK='test-network-ldap'

  # Link the test containers to separate network:
  # NOTE: If the network already exists, test will fail to start.
  docker network create "${DMS_TEST_NETWORK}"

  # Setup local openldap service:
  docker run -d --name "${CONTAINER2_NAME}" \
    --env LDAP_DOMAIN="${FQDN_LOCALHOST_A}" \
    --hostname "${FQDN_LDAP}" \
    --network "${DMS_TEST_NETWORK}" \
    --network-alias 'ldap' \
    --tty \
    dms-openldap # Image name

  export CONTAINER_NAME

  # _setup_ldap uses _replace_by_env_in_file with ENV vars like DOVECOT_TLS with a prefix (eg. DOVECOT_ or LDAP_)
  # Set default implicit container fallback for helpers:
  CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env DOVECOT_PASS_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"
    --env DOVECOT_TLS=no
    --env DOVECOT_USER_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"
    --env ACCOUNT_PROVISIONER=LDAP
    --env PFLOGSUMM_TRIGGER=logrotate
    --env ENABLE_SASLAUTHD=1
    --env LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain
    --env LDAP_BIND_PW=admin
    --env LDAP_QUERY_FILTER_ALIAS="(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))"
    --env LDAP_QUERY_FILTER_DOMAIN="(|(&(mail=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailGroupMember=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailalias=*@%s)(objectClass=PostfixBookMailForward)))"
    --env LDAP_QUERY_FILTER_GROUP="(&(mailGroupMember=%s)(mailEnabled=TRUE))"
    --env LDAP_QUERY_FILTER_SENDERS="(|(&(mail=%s)(mailEnabled=TRUE))(&(mailGroupMember=%s)(mailEnabled=TRUE))(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))(uniqueIdentifier=some.user.id))"
    --env LDAP_QUERY_FILTER_USER="(&(mail=%s)(mailEnabled=TRUE))"
    --env LDAP_START_TLS=no
    --env LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain
    --env LDAP_SERVER_HOST=ldap
    --env PERMIT_DOCKER=container
    --env POSTMASTER_ADDRESS="postmaster@${FQDN_LOCALHOST_A}"
    --env REPORT_RECIPIENT=1
    --env SASLAUTHD_MECHANISMS=ldap
    --env SPOOF_PROTECTION=1
    --env SSL_TYPE='snakeoil'
    --hostname "${FQDN_MAIL}"
    --network "${DMS_TEST_NETWORK}"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
  docker network rm "${DMS_TEST_NETWORK}"
}

# postfix
@test "checking postfix: ldap lookup works correctly" {
  _run_in_container postmap -q "some.user@${FQDN_LOCALHOST_A}" ldap:/etc/postfix/ldap-users.cf
  assert_success
  assert_output "some.user@${FQDN_LOCALHOST_A}"
  _run_in_container postmap -q "postmaster@${FQDN_LOCALHOST_A}" ldap:/etc/postfix/ldap-aliases.cf
  assert_success
  assert_output "some.user@${FQDN_LOCALHOST_A}"
  _run_in_container postmap -q "employees@${FQDN_LOCALHOST_A}" ldap:/etc/postfix/ldap-groups.cf
  assert_success
  assert_output "some.user@${FQDN_LOCALHOST_A}"

  # Test of the user part of the domain is not the same as the uniqueIdentifier part in the ldap
  _run_in_container postmap -q "some.user.email@${FQDN_LOCALHOST_A}" ldap:/etc/postfix/ldap-users.cf
  assert_success
  assert_output "some.user.email@${FQDN_LOCALHOST_A}"

  # Test email receiving from a other domain then the primary domain of the mailserver
  _run_in_container postmap -q "some.other.user@${FQDN_LOCALHOST_B}" ldap:/etc/postfix/ldap-users.cf
  assert_success
  assert_output "some.other.user@${FQDN_LOCALHOST_B}"
  _run_in_container postmap -q "postmaster@${FQDN_LOCALHOST_B}" ldap:/etc/postfix/ldap-aliases.cf
  assert_success
  assert_output "some.other.user@${FQDN_LOCALHOST_B}"
  _run_in_container postmap -q "employees@${FQDN_LOCALHOST_B}" ldap:/etc/postfix/ldap-groups.cf
  assert_success
  assert_output "some.other.user@${FQDN_LOCALHOST_B}"
}

@test "checking postfix: ldap custom config files copied" {
  _run_in_container grep '# Testconfig for ldap integration' /etc/postfix/ldap-users.cf
  assert_success

  _run_in_container grep '# Testconfig for ldap integration' /etc/postfix/ldap-groups.cf
  assert_success

  _run_in_container grep '# Testconfig for ldap integration' /etc/postfix/ldap-aliases.cf
  assert_success
}

@test "checking postfix: ldap config overwrites success" {
  _run_in_container grep 'server_host = ldap' /etc/postfix/ldap-users.cf
  assert_success

  _run_in_container grep 'start_tls = no' /etc/postfix/ldap-users.cf
  assert_success

  _run_in_container grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-users.cf
  assert_success

  _run_in_container grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-users.cf
  assert_success

  _run_in_container grep 'server_host = ldap' /etc/postfix/ldap-groups.cf
  assert_success

  _run_in_container grep 'start_tls = no' /etc/postfix/ldap-groups.cf
  assert_success

  _run_in_container grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-groups.cf
  assert_success

  _run_in_container grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-groups.cf
  assert_success

  _run_in_container grep 'server_host = ldap' /etc/postfix/ldap-aliases.cf
  assert_success

  _run_in_container grep 'start_tls = no' /etc/postfix/ldap-aliases.cf
  assert_success

  _run_in_container grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-aliases.cf
  assert_success

  _run_in_container grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-aliases.cf
  assert_success
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
  _run_in_container grep 'uris = ldap://ldap' /etc/dovecot/dovecot-ldap.conf.ext
  assert_success
  _run_in_container grep 'tls = no' /etc/dovecot/dovecot-ldap.conf.ext
  assert_success
  _run_in_container grep 'base = ou=people,dc=localhost,dc=localdomain' /etc/dovecot/dovecot-ldap.conf.ext
  assert_success
  _run_in_container grep 'dn = cn=admin,dc=localhost,dc=localdomain' /etc/dovecot/dovecot-ldap.conf.ext
  assert_success
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
