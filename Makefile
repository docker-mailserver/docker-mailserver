NAME = tvial/docker-mailserver:testing
THIS_FILE = nuw.make
CONTAINER=from_image mail mail_privacy mail_pop3 mail_smtponly mail_smtponly_without_config mail_override_hostname mail_fail2ban mail_fetchmail mail_disabled_clamav_spamassassin mail_manual_ssl mail_with_ldap mail_postscreen mail_lmtp_ip mail_with_postgrey mail_undef_spam_subject mail_with_relays mail_with_imap
PERF=1

all: clean build-no-cache backup generate-accounts run generate-accounts-after-run fixtures tests clean
all-fast: clean build backup generate-accounts run generate-accounts-after-run fixtures tests clean

no-build: clean backup generate-accounts run generate-accounts-after-run fixtures tests clean

build-no-cache:
	cd test/docker-openldap/ && docker build -f Dockerfile -t ldap --no-cache .
	docker build --no-cache -t $(NAME) .

build:
	cd test/docker-openldap/ && docker build -f Dockerfile -t ldap .
	docker build -t $(NAME) .

backup:
	# if backup directories exist, clean hasn't been called, therefore we shouldn't overwrite it. It still contains the original content.
	@if [ ! -d config.bak ]; then\
  	cp -rp config config.bak; \
	fi
	@if [ ! -d testconfig.bak ]; then\
		cp -rp test/config testconfig.bak ;\
	fi

generate-accounts:
	docker run --rm -e MAIL_USER=user1@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' > test/config/postfix-accounts.cf
	docker run --rm -e MAIL_USER=user2@otherdomain.tld -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf

build_from_image:
	# Nothing to do here

build_mail:
	docker run -d --name mail \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-v "`pwd`/test/onedir":/var/mail-state \
		-e ENABLE_CLAMAV=1 \
		-e SPOOF_PROTECTION=1 \
		-e ENABLE_SPAMASSASSIN=1 \
		-e REPORT_RECIPIENT=user1@localhost.localdomain \
		-e SA_TAG=-5.0 \
		-e SA_TAG2=2.0 \
		-e SA_KILL=3.0 \
		-e SA_SPAM_SUBJECT="SPAM: " \
		-e VIRUSMAILS_DELETE_DELAY=7 \
		-e ENABLE_SRS=1 \
		-e SASL_PASSWD="external-domain.com username:password" \
		-e ENABLE_MANAGESIEVE=1 \
		--cap-add=SYS_PTRACE \
		-e PERMIT_DOCKER=host \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))

build_mail_privacy:
	docker run -d --name mail_privacy \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_CLAMAV=1 \
		-e ENABLE_SPAMASSASSIN=1 \
		-e SA_TAG=-5.0 \
		-e SA_TAG2=2.0 \
		-e SA_KILL=3.0 \
		-e SA_SPAM_SUBJECT="SPAM: " \
		-e VIRUSMAILS_DELETE_DELAY=7 \
		-e SASL_PASSWD="external-domain.com username:password" \
		-e ENABLE_MANAGESIEVE=1 \
		--cap-add=SYS_PTRACE \
		-e PERMIT_DOCKER=host \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_pop3:
	docker run -d --name mail_pop3 \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-v "`pwd`/test/config/letsencrypt":/etc/letsencrypt/live \
		-e ENABLE_POP3=1 \
		-e DMS_DEBUG=0 \
		-e SSL_TYPE=letsencrypt \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_smtponly:
	docker run -d --name mail_smtponly \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e SMTP_ONLY=1 \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e OVERRIDE_HOSTNAME=mail.my-domain.com \
		-t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_smtponly_without_config:
	docker run -d --name mail_smtponly_without_config \
		-e SMTP_ONLY=1 \
		-e ENABLE_LDAP=1 \
		-e PERMIT_DOCKER=network \
		-e OVERRIDE_HOSTNAME=mail.mydomain.com \
		-t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_override_hostname:
	docker run -d --name mail_override_hostname \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e OVERRIDE_HOSTNAME=mail.my-domain.com \
		-h unknown.domain.tld \
		-t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_fail2ban:
	docker run -d --name mail_fail2ban \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_FAIL2BAN=1 \
		-e POSTSCREEN_ACTION=ignore \
		--cap-add=NET_ADMIN \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_fetchmail:
	docker run -d --name mail_fetchmail \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_FETCHMAIL=1 \
		--cap-add=NET_ADMIN \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_disabled_clamav_spamassassin:
	docker run -d --name mail_disabled_clamav_spamassassin \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_CLAMAV=0 \
		-e ENABLE_SPAMASSASSIN=0 \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_manual_ssl:
	docker run -d --name mail_manual_ssl \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e SSL_TYPE=manual \
		-e SSL_CERT_PATH=/tmp/docker-mailserver/letsencrypt/mail.my-domain.com/fullchain.pem \
		-e SSL_KEY_PATH=/tmp/docker-mailserver/letsencrypt/mail.my-domain.com/privkey.pem \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_with_ldap:
	docker run -d --name ldap_for_mail \
		-e LDAP_DOMAIN="localhost.localdomain" \
		-h ldap.my-domain.com -t ldap
	sleep $$(( 15 / $(PERF) ))
	docker run -d --name mail_with_ldap \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_LDAP=1 \
		-e LDAP_SERVER_HOST=ldap \
		-e LDAP_START_TLS=no \
		-e SPOOF_PROTECTION=1 \
		-e LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain \
		-e LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain \
		-e LDAP_BIND_PW=admin \
		-e LDAP_QUERY_FILTER_USER="(&(mail=%s)(mailEnabled=TRUE))" \
		-e LDAP_QUERY_FILTER_GROUP="(&(mailGroupMember=%s)(mailEnabled=TRUE))" \
		-e LDAP_QUERY_FILTER_ALIAS="(&(mailAlias=%s)(mailEnabled=TRUE))" \
		-e LDAP_QUERY_FILTER_DOMAIN="(&(|(mail=*@%s)(mailalias=*@%s)(mailGroupMember=*@%s))(mailEnabled=TRUE))" \
		-e DOVECOT_TLS=no \
		-e DOVECOT_PASS_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))" \
		-e DOVECOT_USER_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))" \
		-e ENABLE_SASLAUTHD=1 \
		-e SASLAUTHD_MECHANISMS=ldap \
		-e SASLAUTHD_LDAP_SERVER=ldap \
		-e SASLAUTHD_LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain \
		-e SASLAUTHD_LDAP_PASSWORD=admin \
		-e SASLAUTHD_LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain \
		-e POSTMASTER_ADDRESS=postmaster@localhost.localdomain \
		-e DMS_DEBUG=0 \
		--link ldap_for_mail:ldap \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_with_imap:
	docker run -d --name mail_with_imap \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_SASLAUTHD=1 \
		-e SASLAUTHD_MECHANISMS=rimap \
		-e SASLAUTHD_MECH_OPTIONS=127.0.0.1 \
		-e POSTMASTER_ADDRESS=postmaster@localhost.localdomain \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_postscreen:
	docker run -d --name mail_postscreen \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e POSTSCREEN_ACTION=enforce \
		--cap-add=NET_ADMIN \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_lmtp_ip:
	docker run -d --name mail_lmtp_ip \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/config/dovecot-lmtp":/etc/dovecot \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_POSTFIX_VIRTUAL_TRANSPORT=1 \
		-e POSTFIX_DAGENT=lmtp:127.0.0.1:24 \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 30 / $(PERF) ))
build_mail_with_postgrey:
	docker run -d --name mail_with_postgrey \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_POSTGREY=1 \
		-e POSTGREY_DELAY=15 \
		-e POSTGREY_MAX_AGE=35 \
		-e POSTGREY_TEXT="Delayed by postgrey" \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 20 / $(PERF) ))
build_mail_undef_spam_subject:
	docker run -d --name mail_undef_spam_subject \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_SPAMASSASSIN=1 \
		-e SA_SPAM_SUBJECT="undef" \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))
build_mail_with_relays:
	docker run -d --name mail_with_relays \
		-v "`pwd`/test/config/relay-hosts":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e RELAY_HOST=default.relay.com \
		-e RELAY_PORT=2525 \
		-e RELAY_USER=smtp_user \
		-e RELAY_PASSWORD=smtp_password \
		--cap-add=SYS_PTRACE \
		-e PERMIT_DOCKER=host \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep $$(( 15 / $(PERF) ))

generate-accounts-after-run:
	docker run --rm -e MAIL_USER=added@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf
  ifneq (,$(filter mail,$(CONTAINER)))
	  docker exec mail addmailuser pass@localhost.localdomain 'may be \a `p^a.*ssword'
		sleep $$(( 10 / $(PERF) ))
  endif

fixtures:
	# Setup sieve & create filtering folder (INBOX/spam)
	$(eval NEEDSSLEEP=false)
  ifneq (,$(filter mail,$(CONTAINER)))
		docker cp "`pwd`/test/config/sieve/dovecot.sieve" mail:/var/mail/localhost.localdomain/user1/.dovecot.sieve
		docker exec mail /bin/sh -c "maildirmake.dovecot /var/mail/localhost.localdomain/user1/.INBOX.spam"
		docker exec mail /bin/sh -c "chown 5000:5000 -R /var/mail/localhost.localdomain/user1/.INBOX.spam"
		sleep $$(( 30 / $(PERF) ))
		# Sending test mails
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-virus.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-external.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-local.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-recipient-delimiter.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user2.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-added.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user-and-cc-local-alias.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-regexp-alias-external.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-regexp-alias-local.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-catchall-local.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/sieve-spam-folder.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/sieve-pipe.txt"
		docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/non-existing-user.txt"

		$(eval NEEDSSLEEP=true)
  endif
  ifneq (,$(filter mail_disabled_clamav_spamassassin,$(CONTAINER)))
		docker exec mail_disabled_clamav_spamassassin /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
		$(eval NEEDSSLEEP=true)
  endif
	# postfix virtual transport lmtp
  ifneq (,$(filter mail_lmtp_ip,$(CONTAINER)))
		docker exec mail_lmtp_ip /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
		$(eval NEEDSSLEEP=true)
  endif
  ifneq (,$(filter mail_privacy,$(CONTAINER)))
		docker exec mail_privacy /bin/sh -c "openssl s_client -quiet -starttls smtp -connect 0.0.0.0:587 < /tmp/docker-mailserver-test/email-templates/send-privacy-email.txt"
		$(eval NEEDSSLEEP=true)
  endif
  ifneq (,$(filter mail_override_hostname,$(CONTAINER)))
		docker exec mail_override_hostname /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
		$(eval NEEDSSLEEP=true)
  endif
  # Wait for mails to be analyzed
	@if [ $(NEEDSSLEEP) = true ]; then \
		echo "sleep $$(( 80 / $(PERF) ))"; \
		sleep $$(( 80 / $(PERF) )); \
	fi

define TEST_template
$(addprefix test_,$(1)):
	./test/bats/bin/bats test/tests-$(1).bats
endef
$(foreach cont,$(CONTAINER),$(eval $(call TEST_template,$(cont))))

tests:
	#./test/bats/bin/bats test/tests.bats
	$(MAKE) -i -f $(THIS_FILE) $(addprefix test_,$(CONTAINER))

run:
	$(MAKE) -f $(THIS_FILE) -j $(addprefix build_,$(CONTAINER))



	# Running tests on $(CONTAINER):

	#$(foreach cont,$(CONTAINER),./test/bats/bin/bats test/tests-$(cont).bats)

#tests:
  # Start tests

#	STATUS=0; \
	for c in $(CONTAINER); do \
		./test/bats/bin/bats test/tests-$$c.bats; \
		STATUS=$$(( $$? + $$STATUS )); \
		docker rm -f $$c; \
	done; \
	exit $$STATUS

	 #$(foreach c,$(CONTAINER),./test/bats/bin/bats test/tests-$c.bats;)

clean:
	# Remove running test containers
	-docker rm -f \
		mail \
		mail_privacy \
		mail_pop3 \
		mail_smtponly \
		mail_smtponly_without_config \
		mail_fail2ban \
		mail_fetchmail \
		mail_disabled_clamav_spamassassin \
		mail_manual_ssl \
		ldap_for_mail \
		mail_with_ldap \
		mail_with_imap \
		mail_lmtp_ip \
		mail_with_postgrey \
		mail_undef_spam_subject \
		mail_postscreen \
		mail_override_hostname \
		mail_with_relays \
		fail-auth-mailer

	@if [ -d config.bak ]; then\
		rm -rf config ;\
		mv config.bak config ;\
	fi
	@if [ -d testconfig.bak ]; then\
		sudo rm -rf test/config ;\
		mv testconfig.bak test/config ;\
	fi
	-sudo rm -rf test/onedir
