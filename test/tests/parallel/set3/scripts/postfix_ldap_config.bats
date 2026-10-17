load "${REPOSITORY_ROOT}/test/helper/common"

source "${REPOSITORY_ROOT}/target/scripts/helpers/log.sh"
source "${REPOSITORY_ROOT}/target/scripts/helpers/utils.sh"
source "${REPOSITORY_ROOT}/target/scripts/startup/setup.d/ldap.sh"

BATS_TEST_NAME_PREFIX='[Postfix LDAP config] '

@test "renders only known settings with a non-empty ENV of the given prefix" {
  export TEST_SEARCH_BASE='ou=users,dc=example,dc=test'
  export TEST_QUERY_FILTER='(&(mail=%s)(objectClass=*))'
  export TEST_START_TLS=''
  export TEST_MESSAGE_SIZE_LIMIT='1000'

  run _postfix_ldap_settings_from_env 'TEST_'
  assert_success
  assert_output "$(printf '%s\n' \
    'search_base = ou=users,dc=example,dc=test' \
    'query_filter = (&(mail=%s)(objectClass=*))')"
}

@test "cleanses config (normalized white-space, no empty values, last key wins)" {
  run _cleanse_config < <(printf '%s\n' \
    'version = 3' \
    'result_attribute = mail' \
    '  server_host      =   ldap://first' \
    'result_attribute = mail, uid' \
    'server_host=ldap://second' \
    'bind_pw =' \
    'query_filter = (mail=%s)')
  assert_success
  assert_output "$(printf '%s\n' \
    'query_filter = (mail=%s)' \
    'result_attribute = mail, uid' \
    'server_host = ldap://second' \
    'version = 3')"
}
