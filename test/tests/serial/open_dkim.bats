load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[OpenDKIM] '
CONTAINER_NAME='dms-test_opendkim'

export IMAGE_NAME
IMAGE_NAME="${NAME:?Image name must be set}"

# WHY IS THIS CONTAINER EVEN CREATED WHEN MOST TESTS DO NOT USE IT?
function setup_file()
{
  _init_with_defaults
  mv "${TEST_TMP_CONFIG}/example-opendkim/" "${TEST_TMP_CONFIG}/opendkim/"
  _common_container_setup
}

function teardown_file() { _default_teardown ; }

# -----------------------------------------------
# --- Actual Tests ------------------------------
# -----------------------------------------------

@test "/etc/opendkim/KeyTable should contain 2 entries" {
  _run_in_container cat '/etc/opendkim/KeyTable'
  assert_success
  __assert_has_entry_in_keytable 'localhost.localdomain'
  __assert_has_entry_in_keytable 'otherdomain.tld'
  _should_output_number_of_lines 2
}

@test "/etc/opendkim/keys/ should contain 2 entries" {
  __should_have_content_in_directory '/etc/opendkim/keys/'
  assert_output --partial 'localhost.localdomain'
  assert_output --partial 'otherdomain.tld'
  _should_output_number_of_lines 2
}

@test "/etc/opendkim.conf contains nameservers copied from /etc/resolv.conf" {
  _run_in_container grep -E \
    '^Nameservers ((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' \
    /etc/opendkim.conf
  assert_success
}

# this set of tests is of low quality.                                                       WHAT? <- DELETE AFTER REWRITE
# It does not test the RSA-Key size properly via openssl or similar                          WHAT??? <- DELETE AFTER REWRITE
# Instead it tests the file-size (here 861) - which may differ with a different domain names WWHHHHHHAAAT??? <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "should create key (size: default)" {
  export CONTAINER_NAME='mail_default_key_size'

  _init_with_defaults
  # _common_container_setup

  __should_generate_dkim_key 6
  __should_have_expected_keyfile '861'
}

# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar <- DELETE AFTER REWRITE
# Instead it tests the file-size (here 861) - which may differ with a different domain names <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "should create key (size: 4096)" {
  export CONTAINER_NAME='mail_key_size_4096'

  _init_with_defaults
  # _common_container_setup

  __should_generate_dkim_key 6 '4096'
  __should_have_expected_keyfile '861'
}

# Instead it tests the file-size (here 511) - which may differ with a different domain names <- DELETE AFTER REWRITE
# This test may be re-used as a global test to provide better test coverage. <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "should create key (size: 2048)" {
  export CONTAINER_NAME='mail_key_size_2048'

  _init_with_defaults
  # _common_container_setup

  __should_generate_dkim_key 6 '2048'
  __should_have_expected_keyfile '511'
}

# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar <- DELETE AFTER REWRITE
# Instead it tests the file-size (here 329) - which may differ with a different domain names <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "should create key (size: 1024)" {
  export CONTAINER_NAME='mail_key_size_1024'

  _init_with_defaults
  # _common_container_setup

  __should_generate_dkim_key 6 '1024'
  __should_have_expected_keyfile '329'
}

# No default config supplied to /tmp/docker-mailserver/opendkim
# Generating key should create keys and tables + TrustedHosts files:
@test "should create keys and config files (with defaults)" {
  export CONTAINER_NAME='mail_dkim_generator_creates_keys_tables_TrustedHosts'

  _init_with_defaults
  # _common_container_setup

  __should_generate_dkim_key 6
  __should_have_key_for_domain 'localhost.localdomain'
  __should_have_key_for_domain 'otherdomain.tld'
  __should_have_tables_trustedhosts_for_domain
}

@test "should create keys and config files (without postfix-accounts.cf)" {
  export CONTAINER_NAME='dkim_without-accounts'

  _init_with_defaults
  rm -f "${TEST_TMP_CONFIG}/postfix-accounts.cf"
  # _common_container_setup

  __should_generate_dkim_key 5
  __should_have_key_for_domain 'localhost.localdomain'
  # NOTE: This would only be valid if supplying the default postfix-accounts.cf:
  # __should_have_key_for_domain 'otherdomain.tld'
  __should_have_tables_trustedhosts_for_domain
}

@test "should create keys and config files (without postfix-virtual.cf)" {
  export CONTAINER_NAME='dkim_without-virtual'

  _init_with_defaults
  rm -f "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  # _common_container_setup

  __should_generate_dkim_key 5
  __should_have_key_for_domain 'localhost.localdomain'
  __should_have_key_for_domain 'otherdomain.tld'
  __should_have_tables_trustedhosts_for_domain
}

@test "should create keys and config files (with custom domains)" {
  export CONTAINER_NAME='dkim_with-domain'

  _init_with_defaults
  rm -f "${TEST_TMP_CONFIG}/postfix-accounts.cf"
  rm -f "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  # _common_container_setup

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

  run cat "${TEST_TMP_CONFIG}/opendkim/KeyTable"
  __assert_has_entry_in_keytable 'domain1.tld'
  __assert_has_entry_in_keytable 'domain2.tld'
  __assert_has_entry_in_keytable 'domain3.tld'
  __assert_has_entry_in_keytable 'domain4.tld'
  _should_output_number_of_lines 4

  run cat "${TEST_TMP_CONFIG}/opendkim/SigningTable"
  __assert_has_entry_in_signingtable 'domain1.tld'
  __assert_has_entry_in_signingtable 'domain2.tld'
  __assert_has_entry_in_signingtable 'domain3.tld'
  __assert_has_entry_in_signingtable 'domain4.tld'
  _should_output_number_of_lines 4
}

@test "should create keys and config files (with custom selector)" {
  export CONTAINER_NAME='dkim_with-selector'

  _init_with_defaults
  rm -f "${TEST_TMP_CONFIG}/postfix-accounts.cf"
  rm -f "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  # _common_container_setup

  __should_generate_dkim_key 4 '2048' 'domain1.tld' 'mailer'
  
  __should_have_key_for_domain 'domain1.tld' 'mailer'
  __should_have_tables_trustedhosts_for_domain

  run cat "${TEST_TMP_CONFIG}/opendkim/KeyTable"
  __assert_has_entry_in_keytable 'domain1.tld' 'mailer'

  run cat "${TEST_TMP_CONFIG}/opendkim/SigningTable"
  __assert_has_entry_in_signingtable 'domain1.tld' 'mailer'
}

function __assert_has_entry_in_keytable() {
  local EXPECTED_DOMAIN=${1}
  local EXPECTED_SELECTOR=${2:-'mail'}
  # EXAMPLE: mail._domainkey.domain1.tld domain1.tld:mail:/etc/opendkim/keys/domain1.tld/mail.private
  assert_output --partial "${EXPECTED_SELECTOR}._domainkey.${EXPECTED_DOMAIN} ${EXPECTED_DOMAIN}:${EXPECTED_SELECTOR}:/etc/opendkim/keys/${EXPECTED_DOMAIN}/${EXPECTED_SELECTOR}.private"
}

function __assert_has_entry_in_signingtable() {
  local EXPECTED_DOMAIN=${1}
  local EXPECTED_SELECTOR=${2:-'mail'}
  # EXAMPLE: *@domain1.tld mail._domainkey.domain1.tld
  assert_output --partial "*@${EXPECTED_DOMAIN} ${EXPECTED_SELECTOR}._domainkey.${EXPECTED_DOMAIN}"
}

function __should_generate_dkim_key() {
  local EXPECTED_LINES=${1}
  local ARG_KEYSIZE=${2}
  local ARG_DOMAINS=${3}
  local ARG_SELECTOR=${4}

  [[ -n ${ARG_KEYSIZE}  ]] && ARG_KEYSIZE="keysize ${ARG_KEYSIZE}"
  [[ -n ${ARG_DOMAINS}  ]] && ARG_DOMAINS="domain '${ARG_DOMAINS}'"
  [[ -n ${ARG_SELECTOR} ]] && ARG_SELECTOR="selector '${ARG_SELECTOR}'"

  run docker run --rm \
    -e LOG_LEVEL='debug' \
    -v "${TEST_TMP_CONFIG}/:/tmp/docker-mailserver/" \
    "${IMAGE_NAME}" /bin/bash -c "open-dkim ${ARG_KEYSIZE} ${ARG_DOMAINS} ${ARG_SELECTOR} | wc -l"

  assert_success
  assert_output "${EXPECTED_LINES}"
}

function __should_have_expected_keyfile() {
  local EXPECTED_KEY_FILESIZE=${1}

  run docker run --rm \
    -v "${TEST_TMP_CONFIG}/opendkim:/etc/opendkim" \
    "${IMAGE_NAME}" /bin/bash -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output "${EXPECTED_KEY_FILESIZE}"
}

function __should_have_key_for_domain() {
  local KEY_DOMAIN=${1}
  local KEY_SELECTOR=${2:-'mail'}

  run docker run --rm \
    -v "${TEST_TMP_CONFIG}/opendkim:/etc/opendkim" \
    "${IMAGE_NAME}" \
    /bin/bash -c "ls -1 /etc/opendkim/keys/${KEY_DOMAIN}/ | grep -E '${KEY_SELECTOR}\.(private|txt)' | wc -l"

  assert_success
  assert_output 2
}

function __should_have_tables_trustedhosts_for_domain() {
  run docker run --rm \
    -v "${TEST_TMP_CONFIG}/opendkim:/etc/opendkim" \
    "${IMAGE_NAME}" \
    /bin/bash -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'| wc -l"

  assert_success
  assert_output 4
}
