load 'test_helper/common'

function setup_file() {
  pushd test/docker-openldap/ || return 1
  docker build -f Dockerfile -t ldap --no-cache .
  popd || return 1

  export DOMAIN='my-domain.com'
  export FQDN_MAIL="mail.${DOMAIN}"
  export FQDN_LDAP="ldap.${DOMAIN}"
  export FQDN_LOCALHOST_A='localhost.localdomain'
  export FQDN_LOCALHOST_B='localhost.otherdomain'
  export DMS_TEST_NETWORK='test-network-ldap'

  # NOTE: If the network already exists, test will fail to start.
  docker network create "${DMS_TEST_NETWORK}"

  docker run -d --name ldap_for_mail \
    --env LDAP_DOMAIN="${FQDN_LOCALHOST_A}" \
    --network "${DMS_TEST_NETWORK}" \
    --network-alias 'ldap' \
    --hostname "${FQDN_LDAP}" \
    --tty \
    ldap # Image name

  # _setup_ldap uses configomat with .ext files and ENV vars like DOVECOT_TLS with a prefix (eg DOVECOT_ or LDAP_)
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)
  docker run -d --name mail_with_ldap \
    -v "${PRIVATE_CONFIG}:/tmp/docker-mailserver" \
    -v "$(pwd)/test/test-files:/tmp/docker-mailserver-test:ro" \
    -e DOVECOT_PASS_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))" \
    -e DOVECOT_TLS=no \
    -e DOVECOT_USER_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))" \
    -e ENABLE_LDAP=1 \
    -e PFLOGSUMM_TRIGGER=logrotate \
    -e ENABLE_SASLAUTHD=1 \
    -e LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain \
    -e LDAP_BIND_PW=admin \
    -e LDAP_QUERY_FILTER_ALIAS="(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))" \
    -e LDAP_QUERY_FILTER_DOMAIN="(|(&(mail=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailGroupMember=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailalias=*@%s)(objectClass=PostfixBookMailForward)))" \
    -e LDAP_QUERY_FILTER_GROUP="(&(mailGroupMember=%s)(mailEnabled=TRUE))" \
    -e LDAP_QUERY_FILTER_SENDERS="(|(&(mail=%s)(mailEnabled=TRUE))(&(mailGroupMember=%s)(mailEnabled=TRUE))(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))(uniqueIdentifier=some.user.id))" \
    -e LDAP_QUERY_FILTER_USER="(&(mail=%s)(mailEnabled=TRUE))" \
    -e LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain \
    -e LDAP_SERVER_HOST=ldap \
    -e LDAP_START_TLS=no \
    -e PERMIT_DOCKER=container \
    -e POSTMASTER_ADDRESS="postmaster@${FQDN_LOCALHOST_A}" \
    -e REPORT_RECIPIENT=1 \
    -e SASLAUTHD_MECHANISMS=ldap \
    -e SPOOF_PROTECTION=1 \
    -e SSL_TYPE='snakeoil' \
    --network "${DMS_TEST_NETWORK}" \
    --hostname "${FQDN_MAIL}" \
    --tty \
    "${NAME}" # Image name

  wait_for_smtp_port_in_container mail_with_ldap
}

function teardown_file() {
  docker rm -f ldap_for_mail mail_with_ldap
  docker network rm "${DMS_TEST_NETWORK}"
}

# processes

@test "checking process: saslauthd (saslauthd server enabled)" {
  run docker exec mail_with_ldap /bin/bash -c "ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
  assert_success
}

# postfix
@test "checking postfix: ldap lookup works correctly" {
  run docker exec mail_with_ldap /bin/sh -c "postmap -q some.user@${FQDN_LOCALHOST_A} ldap:/etc/postfix/ldap-users.cf"
  assert_success
  assert_output "some.user@${FQDN_LOCALHOST_A}"
  run docker exec mail_with_ldap /bin/sh -c "postmap -q postmaster@${FQDN_LOCALHOST_A} ldap:/etc/postfix/ldap-aliases.cf"
  assert_success
  assert_output "some.user@${FQDN_LOCALHOST_A}"
  run docker exec mail_with_ldap /bin/sh -c "postmap -q employees@${FQDN_LOCALHOST_A} ldap:/etc/postfix/ldap-groups.cf"
  assert_success
  assert_output "some.user@${FQDN_LOCALHOST_A}"

  # Test of the user part of the domain is not the same as the uniqueIdentifier part in the ldap
  run docker exec mail_with_ldap /bin/sh -c "postmap -q some.user.email@${FQDN_LOCALHOST_A} ldap:/etc/postfix/ldap-users.cf"
  assert_success
  assert_output "some.user.email@${FQDN_LOCALHOST_A}"

  # Test email receiving from a other domain then the primary domain of the mailserver
  run docker exec mail_with_ldap /bin/sh -c "postmap -q some.other.user@${FQDN_LOCALHOST_B} ldap:/etc/postfix/ldap-users.cf"
  assert_success
  assert_output "some.other.user@${FQDN_LOCALHOST_B}"
  run docker exec mail_with_ldap /bin/sh -c "postmap -q postmaster@${FQDN_LOCALHOST_B} ldap:/etc/postfix/ldap-aliases.cf"
  assert_success
  assert_output "some.other.user@${FQDN_LOCALHOST_B}"
  run docker exec mail_with_ldap /bin/sh -c "postmap -q employees@${FQDN_LOCALHOST_B} ldap:/etc/postfix/ldap-groups.cf"
  assert_success
  assert_output "some.other.user@${FQDN_LOCALHOST_B}"
}

@test "checking postfix: ldap custom config files copied" {
  run docker exec mail_with_ldap /bin/sh -c "grep '# Testconfig for ldap integration' /etc/postfix/ldap-users.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep '# Testconfig for ldap integration' /etc/postfix/ldap-groups.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep '# Testconfig for ldap integration' /etc/postfix/ldap-aliases.cf"
  assert_success
}

@test "checking postfix: ldap config overwrites success" {
  run docker exec mail_with_ldap /bin/sh -c "grep 'server_host = ldap' /etc/postfix/ldap-users.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'start_tls = no' /etc/postfix/ldap-users.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-users.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-users.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'server_host = ldap' /etc/postfix/ldap-groups.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'start_tls = no' /etc/postfix/ldap-groups.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-groups.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-groups.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'server_host = ldap' /etc/postfix/ldap-aliases.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'start_tls = no' /etc/postfix/ldap-aliases.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'search_base = ou=people,dc=localhost,dc=localdomain' /etc/postfix/ldap-aliases.cf"
  assert_success

  run docker exec mail_with_ldap /bin/sh -c "grep 'bind_dn = cn=admin,dc=localhost,dc=localdomain' /etc/postfix/ldap-aliases.cf"
  assert_success
}

# dovecot
@test "checking dovecot: ldap imap connection and authentication works" {
  run docker exec mail_with_ldap /bin/sh -c "nc -w 1 0.0.0.0 143 < /tmp/docker-mailserver-test/auth/imap-ldap-auth.txt"
  assert_success
}

@test "checking dovecot: ldap mail delivery works" {
  run docker exec mail_with_ldap /bin/sh -c "sendmail -f user@external.tld some.user@${FQDN_LOCALHOST_A} < /tmp/docker-mailserver-test/email-templates/test-email.txt"
  sleep 10
  run docker exec mail_with_ldap /bin/sh -c "ls -A /var/mail/${FQDN_LOCALHOST_A}/some.user/new | wc -l"
  assert_success
  assert_output 1
}

@test "checking dovecot: ldap mail delivery works for a different domain then the mailserver" {
  run docker exec mail_with_ldap /bin/sh -c "sendmail -f user@external.tld some.other.user@${FQDN_LOCALHOST_B} < /tmp/docker-mailserver-test/email-templates/test-email.txt"
  sleep 10
  run docker exec mail_with_ldap /bin/sh -c "ls -A /var/mail/${FQDN_LOCALHOST_A}/some.other.user/new | wc -l"
  assert_success
  assert_output 1
}

@test "checking dovecot: ldap config overwrites success" {
  run docker exec mail_with_ldap /bin/sh -c "grep 'uris = ldap://ldap' /etc/dovecot/dovecot-ldap.conf.ext"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "grep 'tls = no' /etc/dovecot/dovecot-ldap.conf.ext"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "grep 'base = ou=people,dc=localhost,dc=localdomain' /etc/dovecot/dovecot-ldap.conf.ext"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "grep 'dn = cn=admin,dc=localhost,dc=localdomain' /etc/dovecot/dovecot-ldap.conf.ext"
  assert_success
}

@test "checking dovecot: postmaster address" {
  run docker exec mail_with_ldap /bin/sh -c "grep 'postmaster_address = postmaster@${FQDN_LOCALHOST_A}' /etc/dovecot/conf.d/15-lda.conf"
  assert_success
}

@test "checking dovecot: quota plugin is disabled" {
 run docker exec mail_with_ldap /bin/sh -c "grep '\$mail_plugins quota' /etc/dovecot/conf.d/10-mail.conf"
 assert_failure
 run docker exec mail_with_ldap /bin/sh -c "grep '\$mail_plugins imap_quota' /etc/dovecot/conf.d/20-imap.conf"
 assert_failure
 run docker exec mail_with_ldap ls /etc/dovecot/conf.d/90-quota.conf
 assert_failure
 run docker exec mail_with_ldap ls /etc/dovecot/conf.d/90-quota.conf.disab
 assert_success
}

@test "checking postfix: dovecot quota absent in postconf" {
  run docker exec mail_with_ldap /bin/bash -c "postconf | grep 'check_policy_service inet:localhost:65265'"
  assert_failure
}

@test "checking spoofing (with LDAP): rejects sender forging" {
  wait_for_smtp_port_in_container_to_respond mail_with_ldap
  run docker exec mail_with_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed.txt | grep 'Sender address rejected: not owned by user'"
  assert_success
}

# ATTENTION: these tests must come after "checking dovecot: ldap mail delivery works" since they will deliver an email which skews the count in said test, leading to failure
@test "checking spoofing: accepts sending as alias (with LDAP)" {
  run docker exec mail_with_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed-alias.txt | grep 'End data with'"
  assert_success
}
@test "checking spoofing: uses senders filter" {
  run docker exec mail_with_ldap /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/ldap-smtp-auth-spoofed-sender-with-filter-exception.txt | grep 'End data with'"
  assert_success
}

# saslauthd
@test "checking saslauthd: sasl ldap authentication works" {
  run docker exec mail_with_ldap bash -c "testsaslauthd -u some.user -p secret"
  assert_success
}

@test "checking saslauthd: ldap smtp authentication" {
  run docker exec mail_with_ldap /bin/sh -c "nc -w 5 0.0.0.0 25 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt | grep 'Authentication successful'"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "openssl s_client -quiet -connect 0.0.0.0:465 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt | grep 'Authentication successful'"
  assert_success
  run docker exec mail_with_ldap /bin/sh -c "openssl s_client -quiet -starttls smtp -connect 0.0.0.0:587 < /tmp/docker-mailserver-test/auth/sasl-ldap-smtp-auth.txt | grep 'Authentication successful'"
  assert_success
}

#
# Pflogsumm delivery check
#

@test "checking pflogsum delivery" {
  # checking default sender is correctly set when env variable not defined
  run docker exec mail_with_ldap grep "mailserver-report@${FQDN_MAIL}" /etc/logrotate.d/maillog
  assert_success

  # checking default logrotation setup
  run docker exec mail_with_ldap grep "weekly" /etc/logrotate.d/maillog
  assert_success
}

#
# supervisor
#

@test "checking restart of process: saslauthd (saslauthd server enabled)" {
  run docker exec mail_with_ldap /bin/bash -c "pkill saslauthd && sleep 10 && ps aux --forest | grep -v grep | grep '/usr/sbin/saslauthd'"
  assert_success
}
