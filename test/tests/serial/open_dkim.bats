load "${REPOSITORY_ROOT}/test/test_helper/common"

export IMAGE_NAME CONTAINER_NAME TEST_FILE

IMAGE_NAME="${NAME:?Image name must be set}"
CONTAINER_NAME='open-dkim'
TEST_FILE='checking OpenDKIM: '

# WHY IS THIS CONTAINER EVEN CREATED WHEN MOST TESTS DO NOT USE IT?
function setup_file
{
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")
  mv "${PRIVATE_CONFIG}/example-opendkim/" "${PRIVATE_CONFIG}/opendkim/"

  docker run -d \
    --name "${CONTAINER_NAME}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "${PWD}/test/test-files":/tmp/docker-mailserver-test:ro \
    -e DEFAULT_RELAY_HOST=default.relay.host.invalid:25 \
    -e PERMIT_DOCKER=host \
    -e LOG_LEVEL='trace' \
    -h mail.my-domain.com \
    -t "${IMAGE_NAME}"

  wait_for_finished_setup_in_container "${CONTAINER_NAME}"
}

function teardown_file
{
  docker rm -f "${CONTAINER_NAME}"
}

# -----------------------------------------------
# --- Actual Tests ------------------------------
# -----------------------------------------------

@test "${TEST_FILE}/etc/opendkim/KeyTable should contain 2 entries" {
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "cat /etc/opendkim/KeyTable | wc -l"
  assert_success
  assert_output 2
}

# TODO piping ls into grep ...
@test "${TEST_FILE}/etc/opendkim/keys/ should contain 2 entries" {
  run docker exec "${CONTAINER_NAME}" /bin/bash -c "ls -l /etc/opendkim/keys/ | grep '^d' | wc -l"
  assert_success
  assert_output 2
}

@test "${TEST_FILE}/etc/opendkim.conf contains nameservers copied from /etc/resolv.conf" {
  run docker exec "${CONTAINER_NAME}" /bin/bash -c \
    "grep -E '^Nameservers ((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' \
    /etc/opendkim.conf"
  assert_success
}

# this set of tests is of low quality.                                                       WHAT? <- DELETE AFTER REWRITE
# It does not test the RSA-Key size properly via openssl or similar                          WHAT??? <- DELETE AFTER REWRITE
# Instead it tests the file-size (here 861) - which may differ with a different domain names WWHHHHHHAAAT??? <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "${TEST_FILE}generator creates default keys size" {
  export CONTAINER_NAME='mail_default_key_size'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  __should_generate_dkim_key 6
  __should_have_expected_keyfile '861'
}

# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar <- DELETE AFTER REWRITE
# Instead it tests the file-size (here 861) - which may differ with a different domain names <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "${TEST_FILE}generator creates key size 4096" {
  export CONTAINER_NAME='mail_key_size_4096'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  __should_generate_dkim_key 6 '4096'
  __should_have_expected_keyfile '861'
}

# Instead it tests the file-size (here 511) - which may differ with a different domain names <- DELETE AFTER REWRITE
# This test may be re-used as a global test to provide better test coverage. <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "${TEST_FILE}generator creates keys size 2048" {
  export CONTAINER_NAME='mail_key_size_2048'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  __should_generate_dkim_key 6 '2048'
  __should_have_expected_keyfile '511'
}

# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar <- DELETE AFTER REWRITE
# Instead it tests the file-size (here 329) - which may differ with a different domain names <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "${TEST_FILE}generator creates keys size 1024" {
  export CONTAINER_NAME='mail_key_size_1024'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  __should_generate_dkim_key 6 '1024'
  __should_have_expected_keyfile '329'
}

# No default config supplied to /tmp/docker-mailserver/opendkim
# Generating key should create keys and tables + TrustedHosts files:
@test "${TEST_FILE}generator creates keys, tables and TrustedHosts" {
  export CONTAINER_NAME='mail_dkim_generator_creates_keys_tables_TrustedHosts'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

  __should_generate_dkim_key 6
  __should_have_key_for_domain 'localhost.localdomain'
  __should_have_key_for_domain 'otherdomain.tld'
  __should_have_tables_trustedhosts_for_domain
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts without postfix-accounts.cf" {
  export CONTAINER_NAME='dkim_without-accounts'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")
  rm -f "${PRIVATE_CONFIG}/postfix-accounts.cf"

  __should_generate_dkim_key 5
  __should_have_key_for_domain 'localhost.localdomain'
  # NOTE: This would only be valid if supplying the default postfix-accounts.cf:
  # __should_have_key_for_domain 'otherdomain.tld'
  __should_have_tables_trustedhosts_for_domain
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts without postfix-virtual.cf" {
  export CONTAINER_NAME='dkim_without-virtual'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")
  rm -f "${PRIVATE_CONFIG}/postfix-virtual.cf"

  __should_generate_dkim_key 5
  __should_have_key_for_domain 'localhost.localdomain'
  __should_have_key_for_domain 'otherdomain.tld'
  __should_have_tables_trustedhosts_for_domain
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts using manual provided domain name" {
  export CONTAINER_NAME='dkim_with-domain'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")
  rm -f "${PRIVATE_CONFIG}/postfix-accounts.cf"
  rm -f "${PRIVATE_CONFIG}/postfix-virtual.cf"

  # generate first key
  __should_generate_dkim_key 4 '2048' 'domain1.tld'
  # generate two additional keys different to the previous one
  __should_generate_dkim_key 2 '2048' 'domain2.tld,domain3.tld'
  # generate an additional key whilst providing already existing domains
  __should_generate_dkim_key 1 '2048' 'domain3.tld,domain4.tld'

  __should_have_key_for_domain 'domain1.tld'
  __should_have_key_for_domain 'domain2.tld'
  __should_have_key_for_domain 'domain3.tld'
  __should_have_key_for_domain 'domain4.tld'
  # NOTE: Without the default account configs, neither of these should be valid:
  # __should_have_key_for_domain 'localhost.localdomain'
  # __should_have_key_for_domain 'otherdomain.tld'

  __should_have_tables_trustedhosts_for_domain

  __should_have_key_in_table 4 'KeyTable' 'domain1.tld|domain2.tld|domain3.tld|domain4.tld'
  # EXAMPLE: mail._domainkey.domain1.tld domain1.tld:mail:/etc/opendkim/keys/domain1.tld/mail.private
  __should_have_key_in_table 4 'SigningTable' 'domain1.tld|domain2.tld|domain3.tld|domain4.tld'
  # EXAMPLE: *@domain1.tld mail._domainkey.domain1.tld
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts using manual provided selector name" {
  export CONTAINER_NAME='dkim_with-selector'

  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")
  rm -f "${PRIVATE_CONFIG}/postfix-accounts.cf"
  rm -f "${PRIVATE_CONFIG}/postfix-virtual.cf"

  __should_generate_dkim_key 4 '2048' 'domain1.tld' 'mailer'
  
  __should_have_key_for_domain 'domain1.tld'
  __should_have_key_with_selector_for_domain 'domain1.tld' 'mailer'
  __should_have_tables_trustedhosts_for_domain

  __should_have_key_in_table 1 'KeyTable' 'domain1.tld'
  __should_have_key_in_table 1 'SigningTable' 'domain1.tld'
}

function __should_generate_dkim_key() {
  local EXPECTED_LINES=${1}
  local ARG_KEYSIZE=${2}
  local ARG_DOMAINS=${3}
  local ARG_SELECTOR=${4}

  [[ -n ${ARG_KEYSIZE}  ]] && ARG_KEYSIZE="keysize ${ARG_KEYSIZE}"
  [[ -n ${ARG_DOMAINS}  ]] && ARG_DOMAINS="domain '${ARG_DOMAINS}'"
  [[ -n ${ARG_SELECTOR} ]] && ARG_SELECTOR="selector '${ARG_SELECTOR}'"

  # rm -rf "${PRIVATE_CONFIG}/opendkim"
  # mkdir -p "${PRIVATE_CONFIG}/opendkim"

  run docker run --rm \
    -e LOG_LEVEL='debug' \
    -v "${PRIVATE_CONFIG}/:/tmp/docker-mailserver/" \
    "${IMAGE_NAME}" /bin/bash -c "open-dkim ${ARG_KEYSIZE} ${ARG_DOMAINS} ${ARG_SELECTOR} | wc -l"

  assert_success
  assert_output "${EXPECTED_LINES}"
}

function __should_have_expected_keyfile() {
  local EXPECTED_KEY_FILESIZE=${1}

  run docker run --rm \
    -v "${PRIVATE_CONFIG}/opendkim:/etc/opendkim" \
    "${IMAGE_NAME}" /bin/bash -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output "${EXPECTED_KEY_FILESIZE}"
}

function __should_have_key_for_domain() {
  local KEY_DOMAIN=${1}

  run docker run --rm \
    -v "${PRIVATE_CONFIG}/opendkim:/etc/opendkim" \
    "${IMAGE_NAME}" \
    /bin/bash -c "ls -1 /etc/opendkim/keys/${KEY_DOMAIN}/ | wc -l"

  assert_success
  assert_output 2
}

function __should_have_key_with_selector_for_domain() {
  local KEY_DOMAIN=${1}
  local KEY_SELECTOR=${2}

  run docker run --rm \
    -v "${PRIVATE_CONFIG}/opendkim:/etc/opendkim" \
    "${IMAGE_NAME}" \
    /bin/bash -c "ls -1 /etc/opendkim/keys/${KEY_DOMAIN}/ | grep -E '${KEY_SELECTOR}\.(private|txt)' | wc -l"

  assert_success
  assert_output 2
}

function __should_have_tables_trustedhosts_for_domain() {
  run docker run --rm \
    -v "${PRIVATE_CONFIG}/opendkim:/etc/opendkim" \
    "${IMAGE_NAME}" \
    /bin/bash -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'| wc -l"

  assert_success
  assert_output 4
}

function __should_have_key_in_table() {
  local EXPECTED_LINES=${1}
  local DKIM_TABLE=${2}
  local KEY_DOMAIN=${3}

  run docker run --rm \
    -v "${PRIVATE_CONFIG}/opendkim:/etc/opendkim" \
    "${IMAGE_NAME}" \
    /bin/bash -c "grep -E '${KEY_DOMAIN}' /etc/opendkim/${DKIM_TABLE} | wc -l"

  assert_success
  assert_output "${EXPECTED_LINES}"
}
