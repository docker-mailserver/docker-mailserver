load 'test_helper/common'

# ! NEEDS SERIAL EXECTION - DO NOT RUN IN PARALLEL

IMAGE_NAME=${NAME:-mailserver-testing:ci}
TEST_NAME_PREFIX='checking setup.sh: '
CONTAINER_NAME=''

function setup_file() {
  # Fail early if the test image is already running:
  assert_not_equal "$(docker ps | grep -o "${NAME}")" "${NAME}"
  # Test may fail if an existing DMS container is running,
  # Which can occur from a prior test failing before reaching `no_container.bats`
  # and that failure not properly handling teardown.

  mkdir -p test/{alias,relay}/config
}

@test "${TEST_NAME_PREFIX}alias list" {
  echo "test@example.org test@forward.com" >./test/alias/config/postfix-virtual.cf

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/alias/config alias list
  assert_success
}

@test "${TEST_NAME_PREFIX}alias add" {
  : >./test/alias/config/postfix-virtual.cf
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/alias/config alias add alias@example.com target1@forward.com
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/alias/config alias add alias@example.com target2@forward.com

  sleep 5

  run /bin/sh -c 'cat ./test/alias/config/postfix-virtual.cf | grep "alias@example.com target1@forward.com,target2@forward.com" | wc -l | grep 1'
  assert_success
}

@test "${TEST_NAME_PREFIX}alias del" {
  # start with a1 -> t1,t2 and a2 -> t1
  echo -e 'alias1@example.org target1@forward.com,target2@forward.com\nalias2@example.org target1@forward.com' >./test/alias/config/postfix-virtual.cf

  # we remove a1 -> t1 ==> a1 -> t2 and a2 -> t1
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/alias/config alias del alias1@example.org target1@forward.com
  run grep "target1@forward.com" ./test/alias/config/postfix-virtual.cf
  assert_output  --regexp "^alias2@example.org +target1@forward.com$"

  run grep "target2@forward.com" ./test/alias/config/postfix-virtual.cf
  assert_output  --regexp "^alias1@example.org +target2@forward.com$"

  # we remove a1 -> t2 ==> a2 -> t1
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/alias/config alias del alias1@example.org target2@forward.com
  run grep "alias1@example.org" ./test/alias/config/postfix-virtual.cf
  assert_failure

  run grep "alias2@example.org" ./test/alias/config/postfix-virtual.cf
  assert_success

  # we remove a2 -> t1 ==> empty
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/alias/config alias del alias2@example.org target1@forward.com
  run grep "alias2@example.org" ./test/alias/config/postfix-virtual.cf
  assert_failure
}

@test "${TEST_NAME_PREFIX}setquota" {
  : >./test/quota/config/dovecot-quotas.cf

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config email add quota_user@example.com test_password
  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config email add quota_user2@example.com test_password

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config quota set quota_user@example.com 12M
  assert_success
  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config quota set 51M quota_user@example.com
  assert_failure
  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config quota set unknown@domain.com 150M
  assert_failure

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config quota set quota_user2 51M
  assert_failure

  run /bin/sh -c 'cat ./test/quota/config/dovecot-quotas.cf | grep -E "^quota_user@example.com\:12M\$" | wc -l | grep 1'
  assert_success

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config quota set quota_user@example.com 26M
  assert_success
  run /bin/sh -c 'cat ./test/quota/config/dovecot-quotas.cf | grep -E "^quota_user@example.com\:26M\$" | wc -l | grep 1'
  assert_success

  run grep "quota_user2@example.com" ./test/alias/config/dovecot-quotas.cf
  assert_failure
}

@test "${TEST_NAME_PREFIX}delquota" {
  : >./test/quota/config/dovecot-quotas.cf

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config email add quota_user@example.com test_password
  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config email add quota_user2@example.com test_password

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config quota set quota_user@example.com 12M
  assert_success
  run /bin/sh -c 'cat ./test/quota/config/dovecot-quotas.cf | grep -E "^quota_user@example.com\:12M\$" | wc -l | grep 1'
  assert_success

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config quota del unknown@domain.com
  assert_failure
  run /bin/sh -c 'cat ./test/quota/config/dovecot-quotas.cf | grep -E "^quota_user@example.com\:12M\$" | wc -l | grep 1'
  assert_success

  run ./setup.sh -i "${IMAGE_NAME}" -p ./test/quota/config quota del quota_user@example.com
  assert_success
  run grep "quota_user@example.com" ./test/alias/config/dovecot-quotas.cf
  assert_failure
}

@test "${TEST_NAME_PREFIX}relay add-domain" {
  : >./test/relay/config/postfix-relaymap.cf
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/relay/config relay add-domain example1.org smtp.relay1.com 2525
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/relay/config relay add-domain example2.org smtp.relay2.com
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/relay/config relay add-domain example3.org smtp.relay3.com 2525
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/relay/config relay add-domain example3.org smtp.relay.com 587

  # check adding
  run /bin/sh -c 'cat ./test/relay/config/postfix-relaymap.cf | grep -e "^@example1.org\s\+\[smtp.relay1.com\]:2525" | wc -l | grep 1'
  assert_success
  # test default port
  run /bin/sh -c 'cat ./test/relay/config/postfix-relaymap.cf | grep -e "^@example2.org\s\+\[smtp.relay2.com\]:25" | wc -l | grep 1'
  assert_success
  # test modifying
  run /bin/sh -c 'cat ./test/relay/config/postfix-relaymap.cf | grep -e "^@example3.org\s\+\[smtp.relay.com\]:587" | wc -l | grep 1'
  assert_success
}

@test "${TEST_NAME_PREFIX}relay add-auth" {
  : >./test/relay/config/postfix-sasl-password.cf
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/relay/config relay add-auth example.org smtp_user smtp_pass
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/relay/config relay add-auth example2.org smtp_user2 smtp_pass2
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/relay/config relay add-auth example2.org smtp_user2 smtp_pass_new

  # test adding
  run /bin/sh -c 'cat ./test/relay/config/postfix-sasl-password.cf | grep -e "^@example.org\s\+smtp_user:smtp_pass" | wc -l | grep 1'
  assert_success
  # test updating
  run /bin/sh -c 'cat ./test/relay/config/postfix-sasl-password.cf | grep -e "^@example2.org\s\+smtp_user2:smtp_pass_new" | wc -l | grep 1'
  assert_success
}

@test "${TEST_NAME_PREFIX}relay exclude-domain" {
  : >./test/relay/config/postfix-relaymap.cf
  ./setup.sh -i "${IMAGE_NAME}" -p ./test/relay/config relay exclude-domain example.org

  run /bin/sh -c 'cat ./test/relay/config/postfix-relaymap.cf | grep -e "^@example.org\s*$" | wc -l | grep 1'
  assert_success
}
