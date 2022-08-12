load 'test_helper/common'

# Globals referenced from `test_helper/common`:
# TEST_NAME (should match the filename, minus the bats extension)

# This is a bare minimal container setup.
# All test-cases run sequentially against the same container instance,
# no state is reset between test-cases.
function setup_file() {
  # Initializes common default vars to prepare a DMS container with:
  init_with_defaults
  # Creates and starts the container:
  common_container_setup
}

function teardown_file() {
  docker rm -f "${TEST_NAME}"
}

@test "checking setup.sh: show usage when no arguments provided" {
  run ./setup.sh
  assert_success
  assert_output --partial "This is the main administration script that you use for all your interactions with"
}

@test "checking setup.sh: exit with error when wrong arguments provided" {
  run ./setup.sh lol troll
  assert_failure
  assert_line --index 0 --partial "The command 'lol troll' is invalid."
}

@test "checking setup.sh: setup.sh email add and login" {
  wait_for_service "${TEST_NAME}" changedetector

  run ./setup.sh -c "${TEST_NAME}" email add setup_email_add@example.com test_password
  assert_success

  value=$(grep setup_email_add@example.com "${TEST_TMP_CONFIG}/postfix-accounts.cf" | awk -F '|' '{print $1}')
  assert_equal "${value}" 'setup_email_add@example.com'

  wait_for_changes_to_be_detected_in_container "${TEST_NAME}"

  wait_for_service "${TEST_NAME}" postfix
  wait_for_service "${TEST_NAME}" dovecot
  sleep 5

  run docker exec "${TEST_NAME}" /bin/bash -c "doveadm auth test -x service=smtp setup_email_add@example.com 'test_password' | grep 'passdb'"
  assert_output "passdb: setup_email_add@example.com auth succeeded"
}

@test "checking setup.sh: setup.sh email list" {
  run ./setup.sh -c "${TEST_NAME}" email list
  assert_success
}

@test "checking setup.sh: setup.sh email update" {
  run ./setup.sh -c "${TEST_NAME}" email add lorem@impsum.org test_test
  assert_success

  initialpass=$(grep lorem@impsum.org "${TEST_TMP_CONFIG}/postfix-accounts.cf" | awk -F '|' '{print $2}')
  [[ -n ${initialpass} ]]

  run ./setup.sh -c "${TEST_NAME}" email update lorem@impsum.org my password
  assert_success

  updatepass=$(grep lorem@impsum.org "${TEST_TMP_CONFIG}/postfix-accounts.cf" | awk -F '|' '{print $2}')
  [[ ${updatepass} != "" ]]
  [[ ${initialpass} != "${updatepass}" ]]

  run docker exec "${TEST_NAME}" doveadm pw -t "${updatepass}" -p 'my password'
  assert_output --partial 'verified'
}

@test "checking setup.sh: setup.sh email del" {
  run ./setup.sh -c "${TEST_NAME}" email del -y lorem@impsum.org
  assert_success

  # TODO
  # delmailuser does not work as expected.
  # Its implementation is not functional, you cannot delete a user data
  # directory in the running container by running a new docker container
  # and not mounting the mail folders (persistance is broken).
  # The add script is only adding the user to account file.

  #  run docker exec "${TEST_NAME}" ls /var/mail/impsum.org/lorem
  #  assert_failure
  run grep lorem@impsum.org "${TEST_TMP_CONFIG}/postfix-accounts.cf"
  assert_failure
}

@test "checking setup.sh: setup.sh email restrict" {
  run ./setup.sh -c "${TEST_NAME}" email restrict
  assert_failure
  run ./setup.sh -c "${TEST_NAME}" email restrict add
  assert_failure
  ./setup.sh -c "${TEST_NAME}" email restrict add send lorem@impsum.org
  run ./setup.sh -c "${TEST_NAME}" email restrict list send
  assert_output --regexp "^lorem@impsum.org.*REJECT"

  run ./setup.sh -c "${TEST_NAME}" email restrict del send lorem@impsum.org
  assert_success
  run ./setup.sh -c "${TEST_NAME}" email restrict list send
  assert_output --partial "Everyone is allowed"

  ./setup.sh -c "${TEST_NAME}" email restrict add receive rec_lorem@impsum.org
  run ./setup.sh -c "${TEST_NAME}" email restrict list receive
  assert_output --regexp "^rec_lorem@impsum.org.*REJECT"
  run ./setup.sh -c "${TEST_NAME}" email restrict del receive rec_lorem@impsum.org
  assert_success
}

# alias
@test "checking setup.sh: setup.sh alias list" {
  run ./setup.sh -c "${TEST_NAME}" alias list
  assert_success
  assert_output --partial "alias1@localhost.localdomain user1@localhost.localdomain"
  assert_output --partial "@localdomain2.com user1@localhost.localdomain"
}

@test "checking setup.sh: setup.sh alias add" {
  ./setup.sh -c "${TEST_NAME}" alias add alias@example.com target1@forward.com
  ./setup.sh -c "${TEST_NAME}" alias add alias@example.com target2@forward.com
  ./setup.sh -c "${TEST_NAME}" alias add alias2@example.org target3@forward.com
  sleep 5
  run grep "alias@example.com target1@forward.com,target2@forward.com" "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  assert_success
}

@test "checking setup.sh: setup.sh alias del" {
  ./setup.sh -c "${TEST_NAME}" alias del alias@example.com target1@forward.com
  run grep "target1@forward.com" "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  assert_failure

  run grep "target2@forward.com" "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  assert_output "alias@example.com target2@forward.com"

  ./setup.sh -c "${TEST_NAME}" alias del alias@example.org target2@forward.com
  run grep "alias@example.org" "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  assert_failure

  run grep "alias2@example.org" "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  assert_success

  ./setup.sh -c "${TEST_NAME}" alias del alias2@example.org target3@forward.com
  run grep "alias2@example.org" "${TEST_TMP_CONFIG}/postfix-virtual.cf"
  assert_failure
}

# quota
@test "checking setup.sh: setup.sh setquota" {
  ./setup.sh -c "${TEST_NAME}" email add quota_user@example.com test_password
  ./setup.sh -c "${TEST_NAME}" email add quota_user2@example.com test_password

  run ./setup.sh -c "${TEST_NAME}" quota set quota_user@example.com 12M
  assert_success
  run ./setup.sh -c "${TEST_NAME}" quota set 51M quota_user@example.com
  assert_failure
  run ./setup.sh -c "${TEST_NAME}" quota set unknown@domain.com 150M
  assert_failure

  run ./setup.sh -c "${TEST_NAME}" quota set quota_user2 51M
  assert_failure

  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/dovecot-quotas.cf | grep -E '^quota_user@example.com\:12M\$' | wc -l | grep 1"
  assert_success

  run ./setup.sh -c "${TEST_NAME}" quota set quota_user@example.com 26M
  assert_success
  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/dovecot-quotas.cf | grep -E '^quota_user@example.com\:26M\$' | wc -l | grep 1"
  assert_success

  run grep "quota_user2@example.com" "${TEST_TMP_CONFIG}/dovecot-quotas.cf"
  assert_failure
}

# `quota_user@example.com` created in previous `setquota` test
@test "checking setup.sh: setup.sh delquota" {
  run ./setup.sh -c "${TEST_NAME}" quota set quota_user@example.com 12M
  assert_success
  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/dovecot-quotas.cf | grep -E '^quota_user@example.com\:12M\$' | wc -l | grep 1"
  assert_success

  run ./setup.sh -c "${TEST_NAME}" quota del unknown@domain.com
  assert_failure
  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/dovecot-quotas.cf | grep -E '^quota_user@example.com\:12M\$' | wc -l | grep 1"
  assert_success

  run ./setup.sh -c "${TEST_NAME}" quota del quota_user@example.com
  assert_success
  run grep "quota_user@example.com" "${TEST_TMP_CONFIG}/dovecot-quotas.cf"
  assert_failure
}

@test "checking setup.sh: setup.sh config dkim help correctly displayed" {
  run ./setup.sh -c "${TEST_NAME}" config dkim help
  assert_success
  assert_line --index 3 --partial "    open-dkim - configure DomainKeys Identified Mail (DKIM)"
}

# debug

@test "checking setup.sh: setup.sh debug fetchmail" {
  run ./setup.sh -c "${TEST_NAME}" debug fetchmail
  assert_failure
  assert_output --partial "fetchmail: normal termination, status 11"
}

@test "checking setup.sh: setup.sh debug login ls" {
  run ./setup.sh -c "${TEST_NAME}" debug login ls
  assert_success
}

@test "checking setup.sh: setup.sh relay add-domain" {
  ./setup.sh -c "${TEST_NAME}" relay add-domain example1.org smtp.relay1.com 2525
  ./setup.sh -c "${TEST_NAME}" relay add-domain example2.org smtp.relay2.com
  ./setup.sh -c "${TEST_NAME}" relay add-domain example3.org smtp.relay3.com 2525
  ./setup.sh -c "${TEST_NAME}" relay add-domain example3.org smtp.relay.com 587

  # check adding
  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/postfix-relaymap.cf | grep -e '^@example1.org\s\+\[smtp.relay1.com\]:2525' | wc -l | grep 1"
  assert_success
  # test default port
  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/postfix-relaymap.cf | grep -e '^@example2.org\s\+\[smtp.relay2.com\]:25' | wc -l | grep 1"
  assert_success
  # test modifying
  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/postfix-relaymap.cf | grep -e '^@example3.org\s\+\[smtp.relay.com\]:587' | wc -l | grep 1"
  assert_success
}

@test "checking setup.sh: setup.sh relay add-auth" {
  ./setup.sh -c "${TEST_NAME}" relay add-auth example.org smtp_user smtp_pass
  ./setup.sh -c "${TEST_NAME}" relay add-auth example2.org smtp_user2 smtp_pass2
  ./setup.sh -c "${TEST_NAME}" relay add-auth example2.org smtp_user2 smtp_pass_new

  # test adding
  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/postfix-sasl-password.cf | grep -e '^@example.org\s\+smtp_user:smtp_pass' | wc -l | grep 1"
  assert_success
  # test updating
  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/postfix-sasl-password.cf | grep -e '^@example2.org\s\+smtp_user2:smtp_pass_new' | wc -l | grep 1"
  assert_success
}

@test "checking setup.sh: setup.sh relay exclude-domain" {
  ./setup.sh -c "${TEST_NAME}" relay exclude-domain example.org

  run /bin/sh -c "cat ${TEST_TMP_CONFIG}/postfix-relaymap.cf | grep -e '^@example.org\s*$' | wc -l | grep 1"
  assert_success
}
