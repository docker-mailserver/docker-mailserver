load "${REPOSITORY_ROOT}/test/helper/common"

source "${REPOSITORY_ROOT}/target/scripts/helpers/log.sh"
source "${REPOSITORY_ROOT}/target/scripts/startup/setup.d/ldap.sh"

BATS_TEST_NAME_PREFIX='[Dovecot LDAP config] '

function setup() {
  TMP_CONFIG_FILE=$(mktemp)
  cp "${REPOSITORY_ROOT}/target/dovecot/auth-ldap.conf.ext" "${TMP_CONFIG_FILE}"
}

function teardown() {
  rm -f "${TMP_CONFIG_FILE}"
}

@test "converts LDAP attribute mappings to Dovecot fields" {
  run _dovecot_ldap_attrs_to_fields \
    'userPrincipalName=user,=uid=5000,=gid=5000,=home=/var/mail/%{user | domain | lower}/%{user | username | lower},=mail=maildir:~/Maildir'
  assert_success
  assert_output --partial 'user = %{ldap:userPrincipalName}'
  assert_output --partial 'uid = 5000'
  assert_output --partial 'gid = 5000'
  assert_output --partial 'home = /var/mail/%{user | domain | lower}/%{user | username | lower}'
  assert_output --partial 'mail_path = ~/Maildir'
}

@test "replaces the passdb fields block" {
  run _dovecot_ldap_replace_fields \
    '    # DOVECOT_PASSDB_FIELDS' \
    'userPrincipalName=user,userPassword=password' \
    "${TMP_CONFIG_FILE}"
  assert_success

  run grep -E '^    user = %\{ldap:userPrincipalName\}$' "${TMP_CONFIG_FILE}"
  assert_success
  run grep -E '^    password = %\{ldap:userPassword\}$' "${TMP_CONFIG_FILE}"
  assert_success
  run grep -E '^    user = %\{ldap:uniqueIdentifier\}$' "${TMP_CONFIG_FILE}"
  assert_failure
}

@test "supports authentication binds without a password field" {
  run _dovecot_ldap_replace_fields \
    '    # DOVECOT_PASSDB_FIELDS' \
    'userPrincipalName=user,userPassword=password' \
    "${TMP_CONFIG_FILE}" \
    yes
  assert_success

  run grep -E '^    password = ' "${TMP_CONFIG_FILE}"
  assert_failure
}
