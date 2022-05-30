load 'test_helper/common'

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_pop3 \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_POP3=1 \
    -e PERMIT_DOCKER=container \
    -h mail.my-domain.com -t "${NAME}"

  wait_for_finished_setup_in_container mail_pop3
}

function teardown_file() {
    docker rm -f mail_pop3
}

#
# pop
#

@test "checking pop: server is ready" {
  run docker exec mail_pop3 /bin/bash -c "nc -w 1 0.0.0.0 110 | grep '+OK'"
  assert_success
}

@test "checking pop: authentication works" {
  run docker exec mail_pop3 /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/pop3-auth.txt"
  assert_success
}

@test "checking pop: added user authentication works" {
  run docker exec mail_pop3 /bin/sh -c "nc -w 1 0.0.0.0 110 < /tmp/docker-mailserver-test/auth/added-pop3-auth.txt"
  assert_success
}

#
# spamassassin
#

@test "checking spamassassin: docker env variables are set correctly (default)" {
  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  assert_success

  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  assert_success

  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  assert_success

  run docker exec mail_pop3 /bin/sh -c "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= .\*\*\*SPAM\*\*\* .'"
  assert_success
}

#
# system
#

@test "checking system: /var/log/mail/mail.log is error free" {
  run docker exec mail_pop3 grep 'non-null host address bits in' /var/log/mail/mail.log
  assert_failure

  run docker exec mail_pop3 grep ': error:' /var/log/mail/mail.log
  assert_failure
}

#
# sieve
#

@test "checking manage sieve: disabled per default" {
  run docker exec mail_pop3 /bin/bash -c "nc -z 0.0.0.0 4190"
  assert_failure
}

#
# PERMIT_DOCKER mynetworks
#
@test "checking PERMIT_DOCKER: my network value" {
  run docker exec mail_pop3 /bin/sh -c "postconf | grep '^mynetworks =' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}/32'"
  assert_success
}
