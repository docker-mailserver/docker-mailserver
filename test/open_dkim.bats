load 'test_helper/common'

export IMAGE_NAME CONTAINER_NAME TEST_FILE

IMAGE_NAME="${NAME:?Image name must be set}"
CONTAINER_NAME='open-dkim'
TEST_FILE='checking OpenDKIM: '

# WHY IS THIS CONTAINER EVEN CREATED WHEN MOST TESTS DO NOT USE IT?
function setup_file
{
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${CONTAINER_NAME}")

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
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_default_key_size)

  # Prepare default key size 4096
  rm -rf "${PRIVATE_CONFIG}/keyDefault"
  mkdir -p "${PRIVATE_CONFIG}/keyDefault"

  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/keyDefault/":/tmp/docker-mailserver/ \
    -v "${PRIVATE_CONFIG}/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "${PRIVATE_CONFIG}/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim | wc -l'

  assert_success
  assert_output 6

  run docker run --rm \
    -v "${PRIVATE_CONFIG}/keyDefault/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" \
    /bin/bash -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 861
}

# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar <- DELETE AFTER REWRITE
# Instead it tests the file-size (here 861) - which may differ with a different domain names <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "${TEST_FILE}generator creates key size 4096" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_key_size_4096)

  rm -rf "${PRIVATE_CONFIG}/key4096"
  mkdir -p "${PRIVATE_CONFIG}/config/key4096"

  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/key2048/":/tmp/docker-mailserver/ \
    -v "${PRIVATE_CONFIG}/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "${PRIVATE_CONFIG}/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim keysize 4096 | wc -l'

  assert_success
  assert_output 6

  run docker run --rm \
    -v "${PRIVATE_CONFIG}/key2048/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" \
    /bin/bash -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 861
}

# Instead it tests the file-size (here 511) - which may differ with a different domain names <- DELETE AFTER REWRITE
# This test may be re-used as a global test to provide better test coverage. <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "${TEST_FILE}generator creates key size 2048" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_key_size_2048)

  rm -rf "${PRIVATE_CONFIG}/key2048"
  mkdir -p "${PRIVATE_CONFIG}/config/key2048"

  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/key2048/":/tmp/docker-mailserver/ \
    -v "${PRIVATE_CONFIG}/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "${PRIVATE_CONFIG}/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim keysize 2048 | wc -l'

  assert_success
  assert_output 6

  run docker run --rm \
    -v "${PRIVATE_CONFIG}/key2048/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" \
    /bin/bash -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 511
}

# this set of tests is of low quality. It does not test the RSA-Key size properly via openssl or similar <- DELETE AFTER REWRITE
# Instead it tests the file-size (here 329) - which may differ with a different domain names <- DELETE AFTER REWRITE

# TODO Needs complete re-write
@test "${TEST_FILE}generator creates key size 1024" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_key_size_1024)

  rm -rf "${PRIVATE_CONFIG}/key1024"
  mkdir -p "${PRIVATE_CONFIG}/key1024"

  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/key1024/":/tmp/docker-mailserver/ \
    -v "${PRIVATE_CONFIG}/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "${PRIVATE_CONFIG}/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim keysize 1024 | wc -l'

  assert_success
  assert_output 6

  run docker run --rm \
    -v "${PRIVATE_CONFIG}/key1024/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" \
    /bin/bash -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 329
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_dkim_generator_creates_keys_tables_TrustedHosts)

  rm -rf "${PRIVATE_CONFIG}/empty"
  mkdir -p "${PRIVATE_CONFIG}/empty"

  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/empty/":/tmp/docker-mailserver/ \
    -v "${PRIVATE_CONFIG}/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "${PRIVATE_CONFIG}/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim | wc -l'

  assert_success
  assert_output 6

  # check keys for localhost.localdomain
  run docker run --rm \
    -v "${PRIVATE_CONFIG}/empty/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'

  assert_success
  assert_output 2

  # check keys for otherdomain.tld
  run docker run --rm \
    -v "${PRIVATE_CONFIG}/empty/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'

  assert_success
  assert_output 2

  # check presence of tables and TrustedHosts
  run docker run --rm \
    -v "${PRIVATE_CONFIG}/empty/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"

  assert_success
  assert_output 4
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts without postfix-accounts.cf" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . )

  rm -rf "${PRIVATE_CONFIG}/without-accounts"
  mkdir -p "${PRIVATE_CONFIG}/without-accounts"

  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/without-accounts/":/tmp/docker-mailserver/ \
    -v "${PRIVATE_CONFIG}/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim | wc -l'

  assert_success
  assert_output 5

  # check keys for localhost.localdomain
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/without-accounts/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'

  assert_success
  assert_output 2

  # check keys for otherdomain.tld
  # run docker run --rm \
  #   -v "${PRIVATE_CONFIG}/without-accounts/opendkim":/etc/opendkim \
  #   "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  # assert_success
  # [ "${output}" -eq 0 ]

  # check presence of tables and TrustedHosts
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/without-accounts/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"

  assert_success
  assert_output 4
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts without postfix-virtual.cf" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${BATS_TEST_NAME}")

  rm -rf "${PRIVATE_CONFIG}/without-virtual"
  mkdir -p "${PRIVATE_CONFIG}/without-virtual"

  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/without-virtual/":/tmp/docker-mailserver/ \
    -v "${PRIVATE_CONFIG}/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim | wc -l'

  assert_success
  assert_output 5

  # check keys for localhost.localdomain
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/without-virtual/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'

  assert_success
  assert_output 2

  # check keys for otherdomain.tld
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/without-virtual/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'

  assert_success
  assert_output 2

  # check presence of tables and TrustedHosts
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/without-virtual/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"

  assert_success
  assert_output 4
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts using manual provided domain name" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${BATS_TEST_NAME}")
  rm -rf "${PRIVATE_CONFIG}/with-domain" && mkdir -p "${PRIVATE_CONFIG}/with-domain"

  # generate first key
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/":/tmp/docker-mailserver/ \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim keysize 2048 domain domain1.tld | wc -l'

  assert_success
  assert_output 4

  # generate two additional keys different to the previous one
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/":/tmp/docker-mailserver/ \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim keysize 2048 domain "domain2.tld,domain3.tld" | wc -l'

  assert_success
  assert_output 2

  # generate an additional key whilst providing already existing domains
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/":/tmp/docker-mailserver/ \
    "${IMAGE_NAME}" /bin/bash -c 'open-dkim keysize 2048 domain "domain3.tld,domain4.tld" | wc -l'

  assert_success
  assert_output 1

  # check keys for domain1.tld
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/domain1.tld/ | wc -l'

  assert_success
  assert_output 2

  # check keys for domain2.tld
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/domain2.tld | wc -l'

  assert_success
  assert_output 2

  # check keys for domain3.tld
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/domain3.tld | wc -l'

  assert_success
  assert_output 2

  # check keys for domain4.tld
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c 'ls -1 /etc/opendkim/keys/domain4.tld | wc -l'

  assert_success
  assert_output 2

  # check presence of tables and TrustedHosts
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys' | wc -l"

  assert_success
  assert_output 4

  # check valid entries actually present in KeyTable
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c \
    "egrep 'domain1.tld|domain2.tld|domain3.tld|domain4.tld' /etc/opendkim/KeyTable | wc -l"

  assert_success
  assert_output 4

  # check valid entries actually present in SigningTable
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-domain/opendkim":/etc/opendkim \
    "${IMAGE_NAME}" /bin/bash -c \
    "egrep 'domain1.tld|domain2.tld|domain3.tld|domain4.tld' /etc/opendkim/SigningTable | wc -l"

  assert_success
  assert_output 4
}

@test "${TEST_FILE}generator creates keys, tables and TrustedHosts using manual provided selector name" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container . "${BATS_TEST_NAME}")
  rm -rf "${PRIVATE_CONFIG}/with-selector" && mkdir -p "${PRIVATE_CONFIG}/with-selector"

  # Generate first key
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-selector/":/tmp/docker-mailserver/ \
    "${IMAGE_NAME:?}" /bin/sh -c "open-dkim keysize 2048 domain 'domain1.tld' selector mailer| wc -l"

  assert_success
  assert_output 4

  # Check keys for domain1.tld
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-selector/opendkim":/etc/opendkim \
    "${IMAGE_NAME:?}" /bin/sh -c 'ls -1 /etc/opendkim/keys/domain1.tld/ | wc -l'

  assert_success
  assert_output 2

  # Check key names with selector for domain1.tld
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-selector/opendkim":/etc/opendkim \
    "${IMAGE_NAME:?}" /bin/sh -c "ls -1 /etc/opendkim/keys/domain1.tld | grep -E 'mailer.private|mailer.txt' | wc -l"

  assert_success
  assert_output 2

  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-selector/opendkim":/etc/opendkim \
    "${IMAGE_NAME:?}" /bin/sh -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys' | wc -l"

  assert_success
  assert_output 4

  # Check valid entries actually present in KeyTable
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-selector/opendkim":/etc/opendkim \
    "${IMAGE_NAME:?}" /bin/sh -c \
    "grep 'domain1.tld' /etc/opendkim/KeyTable | wc -l"

  assert_success
  assert_output 1

  # Check valid entries actually present in SigningTable
  run docker run --rm \
    -e LOG_LEVEL='trace' \
    -v "${PRIVATE_CONFIG}/with-selector/opendkim":/etc/opendkim \
    "${IMAGE_NAME:?}" /bin/sh -c \
    "grep 'domain1.tld' /etc/opendkim/SigningTable | wc -l"

  assert_success
  assert_output 1
}
