load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function teardown() {
    run_teardown_file_if_necessary
}

function setup_file() {
    local PRIVATE_CONFIG
    PRIVATE_CONFIG="$(duplicate_config_for_container . mail_mailcrypt)"
    docker run -d --name mail_mailcrypt \
		-v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
		-e ENABLE_PER_USER_STORAGE_ENCRYPTION=1 \
    -e PER_USER_STORAGE_ENCRYPTION_CURVE="secp384r1" \
    -e PER_USER_STORAGE_ENCRYPTION_SCHEME="CRYPT" \
		-h mail.my-domain.com -t "${NAME}"

    local PRIVATE_CONFIG_TWO
    PRIVATE_CONFIG_TWO="$(duplicate_config_for_container . mail_mailcrypt_defaults)"
    docker run -d --name mail_mailcrypt_defaults \
		-v "${PRIVATE_CONFIG_TWO}":/tmp/docker-mailserver \
		-e ENABLE_PER_USER_STORAGE_ENCRYPTION=1 \
		-h mail.my-domain.com -t "${NAME}"

    wait_for_finished_setup_in_container mail_mailcrypt_defaults
    wait_for_finished_setup_in_container mail_mailcrypt
    
}

function teardown_file() {
    docker rm -f mail_mailcrypt mail_mailcrypt_defaults
}

@test "first" {
  skip 'this test must come first to reliably identify when to run setup_file'
}

#
# per user encryption
#

@test "checking mailcrypt: enabled" {
  run docker exec mail_mailcrypt /bin/bash -c "grep '^#.*auth-passwdfile-mailcrypt' /etc/dovecot/conf.d/10-auth.conf"
  assert_failure
  run docker exec mail_mailcrypt /bin/bash -c "grep '^#.*auth-passwdfile\.inc' /etc/dovecot/conf.d/10-auth.conf"
  assert_success
  run docker exec mail_mailcrypt /bin/bash -c "[[ -f /etc/dovecot/conf.d/10-mailcrypt.conf ]]"
  assert_success
}

@test "checking mailcrypt: PER_USER_STORAGE_ENCRYPTION_CURVE equals secp384r1 (not the default secp521r1)" {
  run docker exec mail_mailcrypt /bin/bash -c "grep 'mail_crypt_curve = secp384r1' /etc/dovecot/conf.d/10-mailcrypt.conf"
  assert_success
}

@test "checking mailcrypt: PER_USER_STORAGE_ENCRYPTION_CURVE equals the default secp521r1" {
  run docker exec mail_mailcrypt_defaults /bin/bash -c "grep 'mail_crypt_curve = secp521r1' /etc/dovecot/conf.d/10-mailcrypt.conf"
  assert_success
}

@test "checking mailcrypt: PER_USER_STORAGE_ENCRYPTION_SCHEME equals the default CRYPT" {
  run docker exec mail_mailcrypt_defaults /bin/bash -c "grep 'scheme=CRYPT' /etc/dovecot/conf.d/auth-passwdfile-mailcrypt.inc"
  assert_success
}

@test "checking mailcrypt: PER_USER_STORAGE_ENCRYPTION_SCHEME equals CRYPT (not the default CRYPT)" {
  docker exec mail_mailcrypt /bin/bash -c "cat /etc/dovecot/conf.d/auth-passwdfile-mailcrypt.inc"
  run docker exec mail_mailcrypt /bin/bash -c "grep 'scheme=CRYPT' /etc/dovecot/conf.d/auth-passwdfile-mailcrypt.inc"
  assert_success
}

@test "checking mailcrypt: setup.sh email add and login" {
  wait_for_service mail_mailcrypt changedetector
  assert_success

  run ./setup.sh -c mail_mailcrypt email add setup_email_add@example.com test_password
  assert_output --partial "<userkey>"
  assert_output --partial "Successfully created setup_email_add@example.com with password protected storage encryption keys"
  assert_success

  value=$(grep setup_email_add@example.com "$(private_config_path mail_mailcrypt)/postfix-accounts.cf" | awk -F '|' '{print $1}')
  [ "${value}" = "setup_email_add@example.com" ]
  assert_success

  wait_for_changes_to_be_detected_in_container mail_mailcrypt

  wait_for_service mail_mailcrypt postfix
  wait_for_service mail_mailcrypt dovecot
  sleep 5

  run docker exec mail_mailcrypt /bin/bash -c "doveadm auth test -x service=smtp setup_email_add@example.com 'test_password' | grep 'passdb'"
  assert_output "passdb: setup_email_add@example.com auth succeeded"
}

@test "checking mailcrypt: setup.sh email update" {
  run ./setup.sh -c mail_mailcrypt email add lorem@impsum.org test_test
  assert_success

  initialpass=$(grep lorem@impsum.org "$(private_config_path mail_mailcrypt)/postfix-accounts.cf" | awk -F '|' '{print $2}')
  [ "${initialpass}" != "" ]
  assert_success

  run ./setup.sh -c mail_mailcrypt email update -p "test_test" lorem@impsum.org my password
  assert_success

  updatepass=$(grep lorem@impsum.org "$(private_config_path mail_mailcrypt)/postfix-accounts.cf" | awk -F '|' '{print $2}')
  [ "${updatepass}" != "" ]
  [ "${initialpass}" != "${updatepass}" ]

  docker exec mail_mailcrypt doveadm pw -t "${updatepass}" -p 'my password' | grep 'verified'
  assert_success
}

@test "last" {
  skip 'this test is only there to reliably mark the end for the teardown_file'
}
