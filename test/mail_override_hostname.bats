load 'test_helper/common'

function setup() {
    run_setup_file_if_necessary
}

function setup_file() {
	docker run --rm -d --name mail_override_hostname \
		-v "$(duplicate_config_for_container .)":/tmp/docker-mailserver \
		-v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e ENABLE_SRS=1 \
		-e OVERRIDE_HOSTNAME=mail.my-domain.com \
		-h unknown.domain.tld \
		-t ${NAME}

    wait_for_smtp_port_in_container mail_override_hostname
    # postfix virtual transport lmtp
	docker exec mail_override_hostname /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
}

@test "first" {
    skip 'only used to call setup_file from setup'
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
# clean exit
#

@test "checking that the container stops cleanly" {
  run docker stop -t 60 mail_override_hostname
  assert_success
}

@test "last" {
    skip 'only used to call teardown_file from teardown'
}
