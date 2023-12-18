load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[OpenDKIM] '
CONTAINER1_NAME='dms-test_opendkim_key-sizes'
CONTAINER2_NAME='dms-test_opendkim_with-config-volume'
CONTAINER3_NAME='dms-test_opendkim_without-config-volume'
CONTAINER4_NAME='dms-test_opendkim_without-accounts'
CONTAINER5_NAME='dms-test_opendkim_without-virtual'
CONTAINER6_NAME='dms-test_opendkim_with-args'

function teardown() { _default_teardown ; }

# TODO: Neither of these are too important, but might be worth covering:
# - May want to also add test cases for log: 'No entries found, no keys to make'
# - May want to also do a redundant 2nd run for matching no log output? (Bad UX?)

@test "should support creating keys of different sizes" {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  __init_container_without_waiting

  # The default size created should be 4096-bit:
  __should_support_creating_key_of_size
  # Explicit sizes:
  __should_support_creating_key_of_size '4096'
  __should_support_creating_key_of_size '2048'
  __should_support_creating_key_of_size '1024'
}

# NOTE: This pre-generated opendkim config was before the alias `localdomain2.com`
# was present or supported by open-dkim? (when sourcing domains from generated vhost entries)
@test "providing config volume should setup /etc/opendkim" {
  export CONTAINER_NAME=${CONTAINER1_NAME}

  _init_with_defaults
  mv "${TEST_TMP_CONFIG}/example-opendkim/" "${TEST_TMP_CONFIG}/opendkim/"
  _common_container_setup

  _run_in_container cat '/etc/opendkim/KeyTable'
  assert_success
  __assert_has_entry_in_keytable 'localhost.localdomain'
  __assert_has_entry_in_keytable 'otherdomain.tld'
  _should_output_number_of_lines 2

  _should_have_content_in_directory '/etc/opendkim/keys/'
  assert_output --partial 'localhost.localdomain'
  assert_output --partial 'otherdomain.tld'
  _should_output_number_of_lines 2

  # /etc/opendkim.conf should contain nameservers copied from /etc/resolv.conf
  _run_in_container grep -E \
    '^Nameservers ((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' \
    /etc/opendkim.conf
  assert_success
}

# No default config supplied to /tmp/docker-mailserver/opendkim
# Generating key should create keys and tables + TrustedHosts files:
@test "should create keys and config files (with defaults)" {
  export CONTAINER_NAME=${CONTAINER3_NAME}

  __init_container_without_waiting

  __should_generate_dkim_key 6
  __assert_outputs_common_dkim_logs

  __should_have_tables_trustedhosts_for_domain

  __should_have_key_for_domain 'localhost.localdomain'
  __should_have_key_for_domain 'localdomain2.com'
  __should_have_key_for_domain 'otherdomain.tld'
}

@test "should create keys and config files (without postfix-accounts.cf)" {
  export CONTAINER_NAME=${CONTAINER4_NAME}

  # Only mount single config file (postfix-virtual.cf):
  __init_container_without_waiting "${PWD}/test/config/postfix-virtual.cf:/tmp/docker-mailserver/postfix-virtual.cf:ro"

  __should_generate_dkim_key 5
  __assert_outputs_common_dkim_logs

  __should_have_tables_trustedhosts_for_domain

  __should_have_key_for_domain 'localhost.localdomain'
  __should_have_key_for_domain 'localdomain2.com'
  # NOTE: This would only be present if supplying the default postfix-accounts.cf:
  __should_not_have_key_for_domain 'otherdomain.tld'
}

@test "should create keys and config files (without postfix-virtual.cf)" {
  export CONTAINER_NAME=${CONTAINER5_NAME}

  # Only mount single config file (postfix-accounts.cf):
  __init_container_without_waiting "${PWD}/test/config/postfix-accounts.cf:/tmp/docker-mailserver/postfix-accounts.cf:ro"

  __should_generate_dkim_key 5
  __assert_outputs_common_dkim_logs

  __should_have_tables_trustedhosts_for_domain

  __should_have_key_for_domain 'localhost.localdomain'
  __should_have_key_for_domain 'otherdomain.tld'
  # NOTE: This would only be present if supplying the default postfix-virtual.cf:
  __should_not_have_key_for_domain 'localdomain2.com'
}

@test "should create keys and config files (with custom domains and selector)" {
  export CONTAINER_NAME=${CONTAINER6_NAME}

  # Create without config volume (creates an empty anonymous volume instead):
  __init_container_without_waiting '/tmp/docker-mailserver'

  # generate first key (with a custom selector)
  __should_generate_dkim_key 4 '1024' 'domain1.tld' 'mailer'
  __assert_outputs_common_dkim_logs
  # generate two additional keys different to the previous one
  __should_generate_dkim_key 2 '1024' 'domain2.tld,domain3.tld'
  __assert_logged_dkim_creation 'domain2.tld'
  __assert_logged_dkim_creation 'domain3.tld'
  # generate an additional key whilst providing already existing domains
  __should_generate_dkim_key 1 '1024' 'domain3.tld,domain4.tld'
  __assert_logged_dkim_creation 'domain4.tld'

  __should_have_tables_trustedhosts_for_domain

  __should_have_key_for_domain 'domain1.tld' 'mailer'
  __should_have_key_for_domain 'domain2.tld'
  __should_have_key_for_domain 'domain3.tld'
  __should_have_key_for_domain 'domain4.tld'
  # This would be created by default (from vhost) if no domain was given to open-dkim:
  __should_not_have_key_for_domain 'localhost.localdomain'
  # Without the default account configs, neither of these should be present:
  __should_not_have_key_for_domain 'otherdomain.tld'
  __should_not_have_key_for_domain 'localdomain2.com'

  _run_in_container cat "/tmp/docker-mailserver/opendkim/KeyTable"
  __assert_has_entry_in_keytable 'domain1.tld' 'mailer'
  __assert_has_entry_in_keytable 'domain2.tld'
  __assert_has_entry_in_keytable 'domain3.tld'
  __assert_has_entry_in_keytable 'domain4.tld'
  _should_output_number_of_lines 4

  _run_in_container cat "/tmp/docker-mailserver/opendkim/SigningTable"
  __assert_has_entry_in_signingtable 'domain1.tld' 'mailer'
  __assert_has_entry_in_signingtable 'domain2.tld'
  __assert_has_entry_in_signingtable 'domain3.tld'
  __assert_has_entry_in_signingtable 'domain4.tld'
  _should_output_number_of_lines 4
}

function __init_container_without_waiting {
  _init_with_defaults
  # Override the default config volume:
  [[ -n ${1} ]] && TEST_CONFIG_VOLUME="${1}"
  _common_container_create
  _common_container_start
}

function __assert_has_entry_in_keytable() {
  local EXPECTED_DOMAIN=${1}
  local EXPECTED_SELECTOR=${2:-mail}

  # EXAMPLE: mail._domainkey.domain1.tld domain1.tld:mail:/etc/opendkim/keys/domain1.tld/mail.private
  assert_output --partial "${EXPECTED_SELECTOR}._domainkey.${EXPECTED_DOMAIN} ${EXPECTED_DOMAIN}:${EXPECTED_SELECTOR}:/etc/opendkim/keys/${EXPECTED_DOMAIN}/${EXPECTED_SELECTOR}.private"
}

function __assert_has_entry_in_signingtable() {
  local EXPECTED_DOMAIN=${1}
  local EXPECTED_SELECTOR=${2:-mail}

  # EXAMPLE: *@domain1.tld mail._domainkey.domain1.tld
  assert_output --partial "*@${EXPECTED_DOMAIN} ${EXPECTED_SELECTOR}._domainkey.${EXPECTED_DOMAIN}"
}

function __assert_logged_dkim_creation() {
  local EXPECTED_DOMAIN=${1}
  local EXPECTED_SELECTOR=${2:-mail}

  assert_output --partial "Creating DKIM private key '/tmp/docker-mailserver/opendkim/keys/${EXPECTED_DOMAIN}/${EXPECTED_SELECTOR}.private'"
}

function __assert_outputs_common_dkim_logs() {
  refute_output --partial 'No entries found, no keys to make'
  assert_output --partial 'Creating DKIM KeyTable'
  assert_output --partial 'Creating DKIM SigningTable'
  assert_output --partial 'Creating DKIM TrustedHosts'
}

function __should_support_creating_key_of_size() {
  local EXPECTED_KEYSIZE=${1:-}

  __should_generate_dkim_key 6 "${EXPECTED_KEYSIZE}"
  __assert_outputs_common_dkim_logs
  __assert_logged_dkim_creation 'localdomain2.com'
  __assert_logged_dkim_creation 'localhost.localdomain'
  __assert_logged_dkim_creation 'otherdomain.tld'

  __should_have_expected_files "${EXPECTED_KEYSIZE:-2048}"
  _run_in_container rm -r /tmp/docker-mailserver/opendkim
}

function __should_generate_dkim_key() {
  local EXPECTED_LINES=${1}
  local ARG_KEYSIZE=${2:-}
  local ARG_DOMAINS=${3:-}
  local ARG_SELECTOR=${4:-}

  local DKIM_CMD='open-dkim'
  [[ -n ${ARG_KEYSIZE}  ]] && DKIM_CMD+=" keysize ${ARG_KEYSIZE}"
  [[ -n ${ARG_DOMAINS}  ]] && DKIM_CMD+=" domain '${ARG_DOMAINS}'"
  [[ -n ${ARG_SELECTOR} ]] && DKIM_CMD+=" selector '${ARG_SELECTOR}'"

  _run_in_container_bash "${DKIM_CMD}"

  assert_success
  _should_output_number_of_lines "${EXPECTED_LINES}"
}

function __should_have_expected_files() {
  local EXPECTED_KEYSIZE=${1:?Keysize must be provided}
  local DKIM_DOMAIN='localhost.localdomain'
  local TARGET_DIR="/tmp/docker-mailserver/opendkim/keys/${DKIM_DOMAIN}"

  # DKIM private key for signing, parse it to verify private key size is correct:
  _run_in_container_bash "openssl rsa -in '${TARGET_DIR}/mail.private' -noout -text"
  assert_success
  assert_line --index 0 "RSA Private-Key: (${EXPECTED_KEYSIZE} bit, 2 primes)"

  # DKIM record, extract public key (base64 encoded, potentially multi-line)
  # - tail to exclude first line,
  # - then sed to extract values within quoted lines, then remove `p=` from the start,
  # - and finally echo to concatenate all lines into single string
  # Next decode and parse it with openssl to verify public-key key size is correct:
  _run_in_container_bash "echo \$( \
    tail -n +2 '${TARGET_DIR}/mail.txt' \
    | sed -nE -e 's/.*\"(.*)\".*/\1/p' \
    | sed -e 's/^p=//' \
  ) | openssl enc -base64 -d | openssl pkey -inform DER -pubin -noout -text
  "
  assert_success
  assert_line --index 0 "RSA Public-Key: (${EXPECTED_KEYSIZE} bit)"

  # Contents is for expected DKIM_DOMAIN and selector (mail):
  _run_in_container cat "${TARGET_DIR}/mail.txt"
  assert_output --regexp "; ----- DKIM key mail for ${DKIM_DOMAIN}$"
}

function __should_have_key_for_domain() {
  local KEY_DOMAIN=${1}
  local KEY_SELECTOR=${2:-mail}

  _should_have_content_in_directory "/tmp/docker-mailserver/opendkim/keys/${KEY_DOMAIN}"

  assert_success
  assert_line "${KEY_SELECTOR}.private"
  assert_line "${KEY_SELECTOR}.txt"
  _should_output_number_of_lines 2
}

function __should_not_have_key_for_domain() {
  local KEY_DOMAIN=${1:?Domain must be provided}
  local KEY_SELECTOR=${2:-mail}
  local TARGET_DIR="/tmp/docker-mailserver/opendkim/keys/${KEY_DOMAIN}"

  _run_in_container_bash "[[ -d ${TARGET_DIR} ]]"
  assert_failure
}

function __should_have_tables_trustedhosts_for_domain() {
  _should_have_content_in_directory '/tmp/docker-mailserver/opendkim'

  assert_success
  assert_line 'keys'
  assert_line 'KeyTable'
  assert_line 'SigningTable'
  assert_line 'TrustedHosts'
}
