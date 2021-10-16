load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

teardown_file() {
    docker rm -f mail_override_hostname_and_domainname mail_non_subdomain_hostname mail_srs_domainname mail_srs_hostname_and_domainname
}

@test "first" {
  skip 'only used to call setup_file from setup'
}

@test "checking configuration: SRS_DOMAINNAME" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_srs_hostname_and_domainname)"
  docker run --rm -d --name mail_srs_hostname_and_domainname \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e PERMIT_DOCKER=network \
    -e DMS_DEBUG=1 \
    -e ENABLE_SRS=1 \
    --domainname sld.tld \
    -h subdomain \
    -t "${NAME}"
  wait_for_smtp_port_in_container mail_srs_hostname_and_domainname

  # Check SRS_DOMAINNAME is not set and the DMS_HOSTNAME_DOMAIN is used
  repeat_until_success_or_timeout 15 docker exec mail_srs_hostname_and_domainname grep "SRS_DOMAIN=sld.tld" /etc/default/postsrsd

  # Ensure container cleanly stops
  run docker stop -t 60 mail_srs_hostname_and_domainname
  assert_success

  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_srs_domainname)"
  docker run --rm -d --name mail_srs_domainname \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e PERMIT_DOCKER=network \
    -e DMS_DEBUG=0 \
    -e ENABLE_SRS=1 \
    -e SRS_DOMAINNAME=srs.sld.tld \
    --domainname sld.tld \
    -h subdomain \
    -t "${NAME}"
  wait_for_smtp_port_in_container mail_srs_domainname

  # Check when SRS_DOMAINNAME is set
  repeat_until_success_or_timeout 15 docker exec mail_srs_domainname grep "SRS_DOMAIN=srs.sld.tld" /etc/default/postsrsd
  
  # Ensure container cleanly stops
  run docker stop -t 60 mail_srs_domainname
  assert_success
}

@test "checking configuration: OVERRIDE_HOSTNAME" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_override_hostname_and_domainname)"
  docker run --rm -d --name mail_override_hostname_and_domainname \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e PERMIT_DOCKER=network \
    -e DMS_DEBUG=0 \
    -e ENABLE_SRS=1 \
    -e OVERRIDE_HOSTNAME=subdomain.sld.tld \
    --domainname sld2.tld \
    -h subdomain2 \
    -t "${NAME}"
  wait_for_smtp_port_in_container mail_override_hostname_and_domainname
  docker exec mail_override_hostname_and_domainname /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"

  # Check container hostname is present
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "hostname | grep ^subdomain2$"
  assert_success

  # Check that it's applied to all of the various configs
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "cat /etc/hosts | grep -E [[:space:]]+subdomain2.sld2.tld"
  assert_success
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "cat /etc/mailname | grep ^sld.tld"
  assert_success
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "postconf -n | grep ^mydomain | grep sld.tld"
  assert_success
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "postconf -n | grep ^myhostname | grep subdomain.sld.tld"
  assert_success
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "doveconf | grep hostname | grep subdomain.sld.tld"
  assert_success
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "cat /etc/opendmarc.conf | grep AuthservID | grep subdomain.sld.tld"
  assert_success
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "cat /etc/opendmarc.conf | grep TrustedAuthservIDs | grep subdomain.sld.tld"
  assert_success
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "cat /etc/amavis/conf.d/05-node_id | grep myhostname | grep subdomain.sld.tld"
  assert_success

  # check in postfix HELO message
  run docker exec mail_override_hostname_and_domainname /bin/bash -c "nc -w 1 0.0.0.0 25 | grep subdomain.sld.tld"
  assert_success

  # check headers of received mail
  run docker exec mail_override_hostname_and_domainname /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l | grep 1"
  assert_success
  run docker exec mail_override_hostname_and_domainname /bin/sh -c "cat /var/mail/localhost.localdomain/user1/new/* | grep subdomain.sld.tld"
  assert_success

  # test whether the container hostname is not found in received mail
  run docker exec mail_override_hostname_and_domainname /bin/sh -c "cat /var/mail/localhost.localdomain/user1/new/* | grep subdomain2.sld2.tld"
  assert_failure

  # postsrsd
  run docker exec mail_override_hostname_and_domainname grep "SRS_DOMAIN=sld.tld" /etc/default/postsrsd
  assert_success

  # postmaster address
  run docker exec mail_override_hostname_and_domainname /bin/sh -c "grep 'postmaster_address = postmaster@sld.tld' /etc/dovecot/conf.d/15-lda.conf"
  assert_success

  # Ensure container cleanly stops
  run docker stop -t 60 mail_override_hostname_and_domainname
  assert_success
}

@test "checking configuration: non-subdomain hostname" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . mail_non_subdomain_hostname)"
	docker run --rm -d --name mail_non_subdomain_hostname \
		-v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-e PERMIT_DOCKER=network \
		-e ENABLE_SRS=1 \
		-e DMS_DEBUG=1 \
		-h domain.com \
		-t "${NAME}"
  wait_for_smtp_port_in_container mail_non_subdomain_hostname
  docker exec mail_non_subdomain_hostname /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"

  # check container hostname is applied correctly
  run docker exec mail_non_subdomain_hostname /bin/bash -c "hostname | grep ^domain.com"
  assert_success
  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/hosts | grep domain.com"
  assert_success

  # Check that it's applied to all of the various configs
  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/mailname | grep ^domain.com"
  assert_success
  run docker exec mail_non_subdomain_hostname /bin/bash -c "postconf -n | grep ^mydomain | grep domain.com"
  assert_success
  run docker exec mail_non_subdomain_hostname /bin/bash -c "postconf -n | grep ^myhostname | grep domain.com"
  assert_success
  run docker exec mail_non_subdomain_hostname /bin/bash -c "doveconf | grep hostname | grep domain.com"
  assert_success
  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/opendmarc.conf | grep AuthservID | grep domain.com"
  assert_success
  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/opendmarc.conf | grep TrustedAuthservIDs | grep domain.com"
  assert_success
  run docker exec mail_non_subdomain_hostname /bin/bash -c "cat /etc/amavis/conf.d/05-node_id | grep myhostname | grep domain.com"
  assert_success

  # check hostname in postfix HELO message
  run docker exec mail_non_subdomain_hostname /bin/bash -c "nc -w 1 0.0.0.0 25 | grep domain.com"
  assert_success

  # check headers of received mail
  run docker exec mail_non_subdomain_hostname /bin/sh -c "ls -A /var/mail/localhost.localdomain/user1/new | wc -l | grep 1"
  assert_success
  run docker exec mail_non_subdomain_hostname /bin/sh -c "cat /var/mail/localhost.localdomain/user1/new/* | grep domain.com"
  assert_success

  # postsrsd
  docker exec mail_non_subdomain_hostname cat /etc/default/postsrsd
  run docker exec mail_non_subdomain_hostname grep "SRS_DOMAIN=domain.com" /etc/default/postsrsd
  assert_success

  # postmaster address is correct
  run docker exec mail_non_subdomain_hostname /bin/sh -c "grep 'postmaster_address = postmaster@domain.com' /etc/dovecot/conf.d/15-lda.conf"
  assert_success

  # Ensure container cleanly stops
  run docker stop -t 60 mail_non_subdomain_hostname
  assert_success
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}
