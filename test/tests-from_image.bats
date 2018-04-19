load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking setup.sh: setup.sh alias list" {
  echo "test@example.org test@forward.com" > ./config/postfix-virtual.cf
  run ./setup.sh -p "./config" alias list
  assert_output --partial "test@example.org test@forward.com"
}

@test "checking setup.sh: setup.sh alias add" {
  ./setup.sh -p "./config" alias add test1@example.org test1@forward.com
  ./setup.sh -p "./config" alias add test1@example.org test2@forward.com

  run /bin/sh -c 'cat ./config/postfix-virtual.cf | grep "test1@example.org test1@forward.com,test2@forward.com" | wc -l | grep 1'
  assert_success
}

@test "checking setup.sh: setup.sh alias del" {
  echo -e 'test1@example.org test1@forward.com,test2@forward.com\ntest2@example.org test1@forward.com' > ./config/postfix-virtual.cf

  ./setup.sh -p "./config" alias del test1@example.org test1@forward.com
  run grep "test1@forward.com" ./config/postfix-virtual.cf
  assert_output  --regexp "^test2@example.org +test1@forward.com$"

  run grep "test2@forward.com" ./config/postfix-virtual.cf
  assert_output  --regexp "^test1@example.org +test2@forward.com$"

  ./setup.sh -p "./config"  alias del test1@example.org test2@forward.com
  run grep "test1@example.org" ./config/postfix-virtual.cf
  assert_failure

  run grep "test2@example.org" ./config/postfix-virtual.cf
  assert_success

  ./setup.sh -p "./config" alias del test2@example.org test1@forward.com
  run grep "test2@example.org" ./config/postfix-virtual.cf
  assert_failure
}

@test "checking configuration: hostname/domainname" {
  run docker run tvial/docker-mailserver:testing
  assert_failure
}

@test "checking opendkim: generator creates default keys size" {
    # Prepare default key size 2048
    rm -rf "$(pwd)/test/config/keyDefault" && mkdir -p "$(pwd)/test/config/keyDefault"
    run docker run --rm \
      -v "$(pwd)/test/config/keyDefault/":/tmp/docker-mailserver/ \
      -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
      -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
      tvial/docker-mailserver:testing /bin/sh -c 'generate-dkim-config | wc -l'
    assert_success
    assert_output 6

  run docker run --rm \
    -v "$(pwd)/test/config/keyDefault/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing \
    /bin/sh -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 511
}

@test "checking opendkim: generator creates key size 2048" {
    # Prepare set key size 2048
    rm -rf "$(pwd)/test/config/key2048" && mkdir -p "$(pwd)/test/config/key2048"
    run docker run --rm \
      -v "$(pwd)/test/config/key2048/":/tmp/docker-mailserver/ \
      -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
      -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
      tvial/docker-mailserver:testing /bin/sh -c 'generate-dkim-config 2048 | wc -l'
    assert_success
    assert_output 6

  run docker run --rm \
    -v "$(pwd)/test/config/key2048/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing \
    /bin/sh -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 511
}

@test "checking opendkim: generator creates key size 1024" {
    # Prepare set key size 1024
    rm -rf "$(pwd)/test/config/key1024" && mkdir -p "$(pwd)/test/config/key1024"
    run docker run --rm \
      -v "$(pwd)/test/config/key1024/":/tmp/docker-mailserver/ \
      -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
      -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
      tvial/docker-mailserver:testing /bin/sh -c 'generate-dkim-config 1024 | wc -l'
    assert_success
    assert_output 6

  run docker run --rm \
    -v "$(pwd)/test/config/key1024/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing \
    /bin/sh -c 'stat -c%s /etc/opendkim/keys/localhost.localdomain/mail.txt'

  assert_success
  assert_output 329
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts" {
  rm -rf "$(pwd)/test/config/empty" && mkdir -p "$(pwd)/test/config/empty"
  run docker run --rm \
    -v "$(pwd)/test/config/empty/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    tvial/docker-mailserver:testing /bin/sh -c 'generate-dkim-config | wc -l'
  assert_success
  assert_output 6
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_success
  assert_output 2
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  assert_success
  assert_output 2
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/empty/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_success
  assert_output 4
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts without postfix-accounts.cf" {
  rm -rf "$(pwd)/test/config/without-accounts" && mkdir -p "$(pwd)/test/config/without-accounts"
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    tvial/docker-mailserver:testing /bin/sh -c 'generate-dkim-config | wc -l'
  assert_success
  assert_output 5
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_success
  assert_output 2
  # Check keys for otherdomain.tld
  # run docker run --rm \
  #   -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
  #   tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  # assert_success
  # [ "$output" -eq 0 ]
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_success
  assert_output 4
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts without postfix-virtual.cf" {
  rm -rf "$(pwd)/test/config/without-virtual" && mkdir -p "$(pwd)/test/config/without-virtual"
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    tvial/docker-mailserver:testing /bin/sh -c 'generate-dkim-config | wc -l'
  assert_success
  assert_output 5
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_success
  assert_output 2
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  assert_success
  assert_output 2
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/without-virtual/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c "ls -1 etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys'|wc -l"
  assert_success
  assert_output 4
}

@test "checking opendkim: generator creates keys, tables and TrustedHosts using domain name" {
  rm -rf "$(pwd)/test/config/with-domain" && mkdir -p "$(pwd)/test/config/with-domain"
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/":/tmp/docker-mailserver/ \
    -v "$(pwd)/test/config/postfix-accounts.cf":/tmp/docker-mailserver/postfix-accounts.cf \
    -v "$(pwd)/test/config/postfix-virtual.cf":/tmp/docker-mailserver/postfix-virtual.cf \
    tvial/docker-mailserver:testing /bin/sh -c 'generate-dkim-config | wc -l'
  assert_success
  assert_output 6
  # Generate key using domain name
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/":/tmp/docker-mailserver/ \
    tvial/docker-mailserver:testing /bin/sh -c 'generate-dkim-domain testdomain.tld | wc -l'
  assert_success
  assert_output 1
  # Check keys for localhost.localdomain
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/localhost.localdomain/ | wc -l'
  assert_success
  assert_output 2
  # Check keys for otherdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/otherdomain.tld | wc -l'
  assert_success
  assert_output 2
  # Check keys for testdomain.tld
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c 'ls -1 /etc/opendkim/keys/testdomain.tld | wc -l'
  assert_success
  assert_output 2
  # Check presence of tables and TrustedHosts
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c "ls -1 /etc/opendkim | grep -E 'KeyTable|SigningTable|TrustedHosts|keys' | wc -l"
  assert_success
  assert_output 4
  # Check valid entries actually present in KeyTable
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c \
    "egrep 'localhost.localdomain|otherdomain.tld|localdomain2.com|testdomain.tld' /etc/opendkim/KeyTable | wc -l"
  assert_success
  assert_output 4
  # Check valid entries actually present in SigningTable
  run docker run --rm \
    -v "$(pwd)/test/config/with-domain/opendkim":/etc/opendkim \
    tvial/docker-mailserver:testing /bin/sh -c \
    "egrep 'localhost.localdomain|otherdomain.tld|localdomain2.com|testdomain.tld' /etc/opendkim/SigningTable | wc -l"
  assert_success
  assert_output 4
}

@test "checking amavis: VIRUSMAILS_DELETE_DELAY override works as expected" {
  run docker run -ti --rm -e VIRUSMAILS_DELETE_DELAY=2 tvial/docker-mailserver:testing /bin/bash -c 'echo $VIRUSMAILS_DELETE_DELAY | grep 2'
  assert_success
}

@test "checking accounts: no error is generated when deleting a user if /tmp/docker-mailserver/postfix-accounts.cf is missing" {
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    tvial/docker-mailserver:testing /bin/sh -c 'delmailuser -y user3@domain.tld'
  assert_success
  [ -z "$output" ]
}

@test "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf even when that file does not exist" {
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    tvial/docker-mailserver:testing /bin/sh -c 'addmailuser user3@domain.tld mypassword'
  assert_success
  run docker run --rm \
    -v "$(pwd)/test/config/without-accounts/":/tmp/docker-mailserver/ \
    tvial/docker-mailserver:testing /bin/sh -c 'grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf'
  assert_success
  [ ! -z "$output" ]
}

@test "checking setup.sh: setup.sh email list" {
  run ./setup.sh -c mail -p "./test/config" email list
  assert_success
}

@test "checking setup.sh: Without arguments: status 1, show help text" {
  run ./setup.sh
  assert_failure
  [ "${lines[0]}" = "Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]" ]
}

@test "checking setup.sh: Wrong arguments" {
  run ./setup.sh lol troll
  assert_failure
  [ "${lines[0]}" = "Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]" ]
}

@test "checking setup.sh: setup.sh debug fetchmail" {
  run ./setup.sh debug fetchmail
  [ "$status" -eq 5 ]
# TODO: Fix output check
 assert_output --partial "fetchmail: no mailservers have been specified." ]
}

@test "checking setup.sh: setup.sh config dkim" {
  run ./setup.sh -p "./test/config"  config dkim
  assert_success
}

@test "checking setup.sh: setup.sh relay add-domain" {
  echo -n > ./test/config/postfix-relaymap.cf
  ./setup.sh -p "./test/config"  relay add-domain example1.org smtp.relay1.com 2525
  ./setup.sh -p "./test/config"  relay add-domain example2.org smtp.relay2.com
  ./setup.sh -p "./test/config"  relay add-domain example3.org smtp.relay3.com 2525
  ./setup.sh -p "./test/config"  relay add-domain example3.org smtp.relay.com 587

  # check adding
  run /bin/sh -c 'cat ./test/config/postfix-relaymap.cf | grep -e "^@example1.org\s\+\[smtp.relay1.com\]:2525" | wc -l | grep 1'
  assert_success
  # test default port
  run /bin/sh -c 'cat ./test/config/postfix-relaymap.cf | grep -e "^@example2.org\s\+\[smtp.relay2.com\]:25" | wc -l | grep 1'
  assert_success
  # test modifying
  run /bin/sh -c 'cat ./test/config/postfix-relaymap.cf | grep -e "^@example3.org\s\+\[smtp.relay.com\]:587" | wc -l | grep 1'
  assert_success
}

@test "checking setup.sh: setup.sh relay add-auth" {
  echo -n > ./test/config/postfix-sasl-password.cf
  ./setup.sh -p "./test/config"  relay add-auth example.org smtp_user smtp_pass
  ./setup.sh -p "./test/config"  relay add-auth example2.org smtp_user2 smtp_pass2
  ./setup.sh -p "./test/config"  relay add-auth example2.org smtp_user2 smtp_pass_new

  # test adding
  run /bin/sh -c 'cat ./test/config/postfix-sasl-password.cf | grep -e "^@example.org\s\+smtp_user:smtp_pass" | wc -l | grep 1'
  assert_success
  # test updating
  run /bin/sh -c 'cat ./test/config/postfix-sasl-password.cf | grep -e "^@example2.org\s\+smtp_user2:smtp_pass_new" | wc -l | grep 1'
  assert_success
}

@test "checking setup.sh: setup.sh relay exclude-domain" {
  echo -n > ./test/config/postfix-relaymap.cf
  ./setup.sh -p "./test/config"  relay exclude-domain example.org

  run /bin/sh -c 'cat ./test/config/postfix-relaymap.cf | grep -e "^@example.org\s*$" | wc -l | grep 1'
  assert_success
}




