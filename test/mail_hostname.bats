load 'test_helper/common'


function setup_file() {
  local PRIVATE_CONFIG

  PRIVATE_CONFIG=$(duplicate_config_for_container . mail_override_hostname)
  docker run --rm -d --name mail_override_hostname \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e PERMIT_DOCKER=network \
    -e ENABLE_SRS=1 \
    -e OVERRIDE_HOSTNAME=mail.my-domain.com \
    -h unknown.domain.tld \
    -t "${NAME}"

  PRIVATE_CONFIG_TWO=$(duplicate_config_for_container . mail_non_subdomain_hostname)
  docker run --rm -d --name mail_non_subdomain_hostname \
    -v "${PRIVATE_CONFIG_TWO}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e PERMIT_DOCKER=network \
    -e ENABLE_SRS=1 \
    --hostname domain.com \
    -t "${NAME}"

  PRIVATE_CONFIG_THREE=$(duplicate_config_for_container . mail_srs_domainname)
  docker run --rm -d --name mail_srs_domainname \
    -v "${PRIVATE_CONFIG_THREE}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e PERMIT_DOCKER=network \
    -e ENABLE_SRS=1 \
    -e SRS_DOMAINNAME='srs.my-domain.com' \
    --domainname 'my-domain.com' \
    --hostname 'mail' \
    -t "${NAME}"

  PRIVATE_CONFIG_FOUR=$(duplicate_config_for_container . mail_domainname)
  docker run --rm -d --name mail_domainname \
    -v "${PRIVATE_CONFIG_FOUR}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e PERMIT_DOCKER=network \
    -e ENABLE_SRS=1 \
    --domainname 'my-domain.com' \
    --hostname 'mail' \
    -t "${NAME}"

  wait_for_smtp_port_in_container mail_override_hostname
  wait_for_smtp_port_in_container mail_non_subdomain_hostname
  wait_for_smtp_port_in_container mail_srs_domainname
  wait_for_smtp_port_in_container mail_domainname

  # postfix virtual transport lmtp
  docker exec mail_override_hostname /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  docker exec mail_non_subdomain_hostname /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
}

function teardown_file() {
  docker rm -f mail_override_hostname mail_non_subdomain_hostname mail_srs_domainname mail_domainname
}

@test "checking SRS: SRS_DOMAINNAME is used correctly" {
  repeat_until_success_or_timeout 15 docker exec mail_srs_domainname grep "SRS_DOMAIN=srs.my-domain.com" /etc/default/postsrsd
}

@test "checking SRS: DOMAINNAME is handled correctly" {
  repeat_until_success_or_timeout 15 docker exec mail_domainname grep "SRS_DOMAIN=my-domain.com" /etc/default/postsrsd
}

@test "checking configuration: hostname/domainname override: check container hostname is applied correctly" {
  run docker exec mail_override_hostname /bin/bash -c "hostname | grep unknown.domain.tld"
  assert_success
}

@test "checking configuration: hostname/domainname override: check overriden hostname is applied to all configs" {
  run docker exec mail_override_hostname /bin/bash -c "cat /etc/mailname | grep my-domain.com"
  assert_success

  run docker exec mail_override_hostname /bin/bash -c "postconf -n | grep mydomain | grep my-domain.com"
  assert_success

  run docker exec mail_override_hostname /bin/bash -c "postconf -n | grep myhostname | grep mail.my-domain.com"
  assert_success

  run docker exec mail_override_hostname /bin/bash -c "doveconf | grep hostname | grep mail.my-domain.com"
  assert_success

  run docker exec mail_override_hostname /bin/bash -c "cat /etc/opendmarc.conf | grep AuthservID | grep mail.my-domain.com"
  assert_success

  run docker exec mail_override_hostname /bin/bash -c "cat /etc/opendmarc.conf | grep TrustedAuthservIDs | grep mail.my-domain.com"
  assert_success

  run docker exec mail_override_hostname /bin/bash -c "cat /etc/amavis/conf.d/05-node_id | grep myhostname | grep mail.my-domain.com"
  assert_success
}

@test "checking configuration: hostname/domainname override: check hostname in postfix HELO message" {
  run docker exec mail_override_hostname /bin/bash -c "nc -w 1 0.0.0.0 25 | grep mail.my-domain.com"
  assert_success
}

@test "checking configuration: hostname/domainname override: check headers of received mail" {
  run docker exec mail_override_hostname /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l | grep 1"
  assert_success

  run docker exec mail_override_hostname /bin/sh -c "cat /var/mail/localhost.localdomain/user1/new/* | grep mail.my-domain.com"
  assert_success

  # test whether the container hostname is not found in received mail
  run docker exec mail_override_hostname /bin/sh -c "cat /var/mail/localhost.localdomain/user1/new/* | grep unknown.domain.tld"
  assert_failure
}

@test "checking SRS: OVERRIDE_HOSTNAME is handled correctly" {
  run docker exec mail_override_hostname grep "SRS_DOMAIN=my-domain.com" /etc/default/postsrsd
  assert_success
}

@test "checking dovecot: postmaster address" {
  run docker exec mail_override_hostname /bin/sh -c "grep 'postmaster_address = postmaster@my-domain.com' /etc/dovecot/conf.d/15-lda.conf"
  assert_success
}

#
# non-subdomain tests
#

@test "checking configuration: non-subdomain: check container hostname is applied correctly" {
  run docker exec mail_non_subdomain_hostname /bin/bash -c "hostname | grep domain.com"
  assert_success
}

@test "checking configuration: non-subdomain: check overriden hostname is applied to all configs" {
  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/mailname | grep domain.com"
  assert_success

  run docker exec mail_non_subdomain_hostname /bin/bash -c "postconf -n | grep mydomain | grep domain.com"
  assert_success

  run docker exec mail_non_subdomain_hostname /bin/bash -c "postconf -n | grep myhostname | grep domain.com"
  assert_success

  run docker exec mail_non_subdomain_hostname /bin/bash -c "doveconf | grep hostname | grep domain.com"
  assert_success

  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/opendmarc.conf | grep AuthservID | grep domain.com"
  assert_success

  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/opendmarc.conf | grep TrustedAuthservIDs | grep domain.com"
  assert_success

  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/amavis/conf.d/05-node_id | grep myhostname | grep domain.com"
  assert_success
}

@test "checking configuration: non-subdomain: check hostname in postfix HELO message" {
  run docker exec mail_non_subdomain_hostname /bin/bash -c "nc -w 1 0.0.0.0 25 | grep domain.com"
  assert_success
}

@test "checking configuration: non-subdomain: check headers of received mail" {
  run docker exec mail_non_subdomain_hostname /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l | grep 1"
  assert_success

  run docker exec mail_non_subdomain_hostname /bin/sh -c "cat /var/mail/localhost.localdomain/user1/new/* | grep domain.com"
  assert_success
}

@test "checking SRS: non-subdomain is handled correctly" {
  docker exec mail_non_subdomain_hostname cat /etc/default/postsrsd
  run docker exec mail_non_subdomain_hostname grep "SRS_DOMAIN=domain.com" /etc/default/postsrsd
  assert_success
}

@test "checking dovecot: non-subdomain postmaster address" {
  run docker exec mail_non_subdomain_hostname /bin/sh -c "grep 'postmaster_address = postmaster@domain.com' /etc/dovecot/conf.d/15-lda.conf"
  assert_success
}

#
# clean exit
#

@test "checking that the container stops cleanly: mail_override_hostname" {
  run docker stop -t 60 mail_override_hostname
  assert_success
}

@test "checking that the container stops cleanly: mail_non_subdomain_hostname" {
  run docker stop -t 60 mail_non_subdomain_hostname
  assert_success
}

@test "checking that the container stops cleanly: mail_srs_domainname" {
  run docker stop -t 60 mail_srs_domainname
  assert_success
}

@test "checking that the container stops cleanly: mail_domainname" {
  run docker stop -t 60 mail_domainname
  assert_success
}
