load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Rspamd] (DKIM) '
CONTAINER_NAME='dms-test_rspamd-dkim'

DOMAIN_NAME='fixed.com'
SIGNING_CONF_FILE='/etc/rspamd/override.d/dkim_signing.conf'

function setup_file() {
  _init_with_defaults

  # Comment for maintainers about `PERMIT_DOCKER=host`:
  # https://github.com/docker-mailserver/docker-mailserver/pull/2815/files#r991087509
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_RSPAMD=1
    --env ENABLE_OPENDKIM=0
    --env ENABLE_OPENDMARC=0
    --env ENABLE_POLICYD_SPF=0
    --env LOG_LEVEL=trace
    --env OVERRIDE_HOSTNAME="mail.${DOMAIN_NAME}"
  )

  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_service rspamd-redis
  _wait_for_service rspamd
}

# We want each test to start with a clean state.
function teardown() {
  __remove_signing_config_file
  _run_in_container rm -rf /tmp/docker-mailserver/rspamd/dkim
  assert_success
}

function teardown_file() { _default_teardown ; }

@test 'log level is applied correctly' {
  _run_in_container setup config dkim -vv help
  __log_is_free_of_warnings_and_errors
  assert_output --partial 'Enabled trace-logging'

  _run_in_container setup config dkim -v help
  __log_is_free_of_warnings_and_errors
  assert_output --partial 'Enabled debug-logging'
}

@test 'help message is properly shown' {
  _run_in_container setup config dkim help
  __log_is_free_of_warnings_and_errors
  assert_output --partial 'Showing usage message now'
  assert_output --partial 'rspamd-dkim - Configure DKIM (DomainKeys Identified Mail)'
}

@test 'default signing config is created if it does not exist and not overwritten' {
  # Required pre-condition: no default configuration is present
  __remove_signing_config_file

  __create_key
  assert_success
  __log_is_free_of_warnings_and_errors
  assert_output --partial "Supplying a default configuration ('${SIGNING_CONF_FILE}')"
  refute_output --partial "'${SIGNING_CONF_FILE}' exists, not supplying a default"
  assert_output --partial "Finished DKIM key creation"
  _run_in_container_bash "[[ -f ${SIGNING_CONF_FILE} ]]"
  assert_success
  _exec_in_container_bash "echo 'blabla' >${SIGNING_CONF_FILE}"
  local INITIAL_SHA512_SUM=$(_exec_in_container sha512sum "${SIGNING_CONF_FILE}")

  __create_key
  __log_is_free_of_warnings_and_errors
  refute_output --partial "Supplying a default configuration ('${SIGNING_CONF_FILE}')"
  assert_output --partial "'${SIGNING_CONF_FILE}' exists, not supplying a default"
  assert_output --partial "Finished DKIM key creation"
  local SECOND_SHA512_SUM=$(_exec_in_container sha512sum "${SIGNING_CONF_FILE}")
  assert_equal "${INITIAL_SHA512_SUM}" "${SECOND_SHA512_SUM}"
}

@test 'default directories and files are created' {
  __create_key
  assert_success

  _count_files_in_directory_in_container /tmp/docker-mailserver/rspamd/dkim/ 3
  _run_in_container_bash "[[ -f ${SIGNING_CONF_FILE} ]]"
  assert_success

  __check_path_in_signing_config "/tmp/docker-mailserver/rspamd/dkim/rsa-2048-mail-${DOMAIN_NAME}.private.txt"
  __check_selector_in_signing_config 'mail'
}

@test "argument 'domain' is applied correctly" {
  for DOMAIN in 'blabla.org' 'someother.com' 'random.de'; do
    _run_in_container setup config dkim domain "${DOMAIN}"
    assert_success
    assert_line --partial "Domain set to '${DOMAIN}'"

    local BASE_FILE_NAME="/tmp/docker-mailserver/rspamd/dkim/rsa-2048-mail-${DOMAIN}"
    __check_key_files_are_present "${BASE_FILE_NAME}"
    __check_path_in_signing_config "${BASE_FILE_NAME}.private.txt"
    __remove_signing_config_file
  done
}

@test "argument 'keytype' is applied correctly" {
  _run_in_container setup config dkim keytype foobar
  assert_failure
  assert_line --partial "Unknown keytype 'foobar'"

  for KEYTYPE in 'rsa' 'ed25519'; do
    _run_in_container setup config dkim keytype "${KEYTYPE}"
    assert_success
    assert_line --partial "Keytype set to '${KEYTYPE}'"

    local BASE_FILE_NAME="/tmp/docker-mailserver/rspamd/dkim/ed25519-mail-${DOMAIN_NAME}"
    [[ ${KEYTYPE} == 'rsa' ]] && BASE_FILE_NAME="/tmp/docker-mailserver/rspamd/dkim/rsa-2048-mail-${DOMAIN_NAME}"
    __check_key_files_are_present "${BASE_FILE_NAME}"

    _run_in_container grep ".*k=${KEYTYPE};.*" "${BASE_FILE_NAME}.public.txt"
    assert_success
    _run_in_container grep ".*k=${KEYTYPE};.*" "${BASE_FILE_NAME}.public.dns.txt"
    assert_success
    __check_path_in_signing_config "${BASE_FILE_NAME}.private.txt"
    __remove_signing_config_file
  done
}

@test "argument 'selector' is applied correctly" {
  for SELECTOR in 'foo' 'bar' 'baz'; do
    __create_key 'rsa' "${SELECTOR}"
    assert_success
    assert_line --partial "Selector set to '${SELECTOR}'"

    local BASE_FILE_NAME="/tmp/docker-mailserver/rspamd/dkim/rsa-2048-${SELECTOR}-${DOMAIN_NAME}"
    __check_key_files_are_present "${BASE_FILE_NAME}"
    _run_in_container grep "^${SELECTOR}\._domainkey.*" "${BASE_FILE_NAME}.public.txt"
    assert_success

    __check_rsa_keys 2048 "${SELECTOR}-${DOMAIN_NAME}"
    __check_path_in_signing_config "${BASE_FILE_NAME}.private.txt"
    __check_selector_in_signing_config "${SELECTOR}"
    __remove_signing_config_file
  done
}

@test "argument 'keysize' is applied correctly for RSA keys" {
  for KEYSIZE in 1024 2048 4096; do
    __create_key 'rsa' 'mail' "${DOMAIN_NAME}" "${KEYSIZE}"
    assert_success
    __log_is_free_of_warnings_and_errors
    assert_line --partial "Keysize set to '${KEYSIZE}'"
    __check_rsa_keys "${KEYSIZE}" "mail-${DOMAIN_NAME}"
    __remove_signing_config_file
  done
}

@test "when 'keytype=ed25519' is set, setting custom 'keysize' is rejected" {
  __create_key 'ed25519' 'mail' "${DOMAIN_NAME}" 4096
  assert_failure
  assert_line --partial "Chosen keytype does not accept the 'keysize' argument"
}

@test "setting all arguments to a custom value works" {
  local KEYTYPE='ed25519'
  local SELECTOR='someselector'
  local DOMAIN='dms.org'

  __create_key "${KEYTYPE}" "${SELECTOR}" "${DOMAIN}"
  assert_success
  __log_is_free_of_warnings_and_errors

  assert_line --partial "Keytype set to '${KEYTYPE}'"
  assert_line --partial "Selector set to '${SELECTOR}'"
  assert_line --partial "Domain set to '${DOMAIN}'"

  local BASE_FILE_NAME="/tmp/docker-mailserver/rspamd/dkim/${KEYTYPE}-${SELECTOR}-${DOMAIN}"
  __check_path_in_signing_config "${BASE_FILE_NAME}.private.txt"
  __check_selector_in_signing_config 'someselector'
}

# Create DKIM keys.
#
# @param ${1} = keytype (default: rsa)
# @param ${2} = selector (default: mail)
# @param ${3} = domain (default: ${DOMAIN})
# @param ${4} = keysize (default: 2048)
function __create_key() {
  local KEYTYPE=${1:-rsa}
  local SELECTOR=${2:-mail}
  local DOMAIN=${3:-${DOMAIN_NAME}}
  local KEYSIZE=${4:-2048}

  _run_in_container setup config dkim \
    keytype "${KEYTYPE}"              \
    keysize "${KEYSIZE}"              \
    selector "${SELECTOR}"            \
    domain "${DOMAIN}"
}

# Check whether an RSA key is created successfully and correctly
# for a specific key size.
#
# @param ${1} = key size
# @param ${2} = name of the selector and domain name (as one string)
function __check_rsa_keys() {
  local KEYSIZE=${1:?Keysize must be supplied to __check_rsa_keys}
  local SELECTOR_AND_DOMAIN=${2:?Selector and domain name must be supplied to __check_rsa_keys}
  local BASE_FILE_NAME="/tmp/docker-mailserver/rspamd/dkim/rsa-${KEYSIZE}-${SELECTOR_AND_DOMAIN}"

  __check_key_files_are_present "${BASE_FILE_NAME}"
  __check_path_in_signing_config "${BASE_FILE_NAME}.private.txt"

  # Check the private key matches the specification
  _run_in_container_bash "openssl rsa -in '${BASE_FILE_NAME}.private.txt' -noout -text"
  assert_success
  assert_line --index 0 "RSA Private-Key: (${KEYSIZE} bit, 2 primes)"

  # Check the public key matches the specification
  #
  # We utilize the file for the DNS record contents which is already created
  # by the Rspamd DKIM helper script. This makes parsing easier here.
  local PUBKEY PUBKEY_INFO
  PUBKEY=$(_exec_in_container_bash "grep -o 'p=.*' ${BASE_FILE_NAME}.public.dns.txt")
  _run_in_container_bash "openssl enc -base64 -d <<< ${PUBKEY#p=} | openssl pkey -inform DER -pubin -noout -text"
  assert_success
  assert_line --index 0 "RSA Public-Key: (${KEYSIZE} bit)"
}

# Verify that all DKIM key files are present.
#
# @param ${1} = base file name that all DKIM key files have
function __check_key_files_are_present() {
  local BASE_FILE_NAME="${1:?Base file name must be supplied to __check_key_files_are_present}"
  for FILE in ${BASE_FILE_NAME}.{public.txt,public.dns.txt,private.txt}; do
    _run_in_container_bash "[[ -f ${FILE} ]]"
    assert_success
  done
}

# Check whether `path = .*` is set correctly in the signing configuration file.
#
# @param ${1} = file name that `path` should be set to
function __check_path_in_signing_config() {
  local BASE_FILE_NAME=${1:?Base file name must be supplied to __check_path_in_signing_config}
  _run_in_container grep "[[:space:]]*path = \"${BASE_FILE_NAME}\";" "${SIGNING_CONF_FILE}"
  assert_success
}

# Check whether `selector = .*` is set correctly in the signing configuration file.
#
# @param ${1} = name that `selector` should be set to
function __check_selector_in_signing_config() {
  local SELECTOR=${1:?Selector name must be supplied to __check_selector_in_signing_config}
  _run_in_container grep "[[:space:]]*selector = \"${SELECTOR}\";" "${SIGNING_CONF_FILE}"
  assert_success
}

# Check whether the script output is free of warnings and errors.
function __log_is_free_of_warnings_and_errors() {
  assert_success
  refute_output --partial '[  WARN   ]'
  refute_output --partial '[  ERROR  ]'
}

# Remove the signing configuration file inside the container.
function __remove_signing_config_file() {
  _exec_in_container rm -f "${SIGNING_CONF_FILE}"
}
