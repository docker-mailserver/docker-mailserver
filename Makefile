NAME = tvial/docker-mailserver:testing

all: build-no-cache generate-accounts run fixtures tests clean
all-fast: build generate-accounts run fixtures tests clean
no-build: generate-accounts run fixtures tests clean

build-no-cache:
	cd test/docker-openldap/ && docker build -f Dockerfile -t ldap --no-cache .
	docker build --no-cache -t $(NAME) .

build:
	cd test/docker-openldap/ && docker build -f Dockerfile -t ldap .
	docker build -t $(NAME) .

generate-accounts:
	docker run --rm -e MAIL_USER=user1@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' > test/config/postfix-accounts.cf
	docker run --rm -e MAIL_USER=user2@otherdomain.tld -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf

run:
	docker run -d --name mail \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-v "`pwd`/test/onedir":/var/mail-state \
		-e ENABLE_POP3=$(ENABLE_POP3) \
		-e ENABLE_FAIL2BAN=$(ENABLE_FAIL2BAN) \
		-e ENABLE_MANAGESIEVE=$(ENABLE_MANAGESIEVE) \
		-e ENABLE_CLAMAV=$(ENABLE_CLAMAV) \
		-e ENABLE_SPAMASSASSIN=$(ENABLE_SPAMASSASSIN) \
		-e SMTP_ONLY=$(SMTP_ONLY) \
		-e SA_TAG=$(SA_TAG) \
		-e SA_TAG2=$(SA_TAG2) \
		-e SA_KILL=$(SA_KILL) \
		-e SASL_PASSWD="$(SASL_PASSWD)" \
		-e ONE_DIR=$(ONE_DIR) \
		-e DMS_DEBUG=$(DMS_DEBUG) \
		-h mail.my-domain.com -t $(NAME)

	# Wait for containers to fully start
	sleep 15

fixtures:
	cp config/postfix-accounts.cf config/postfix-accounts.cf.bak
	# Setup sieve & create filtering folder (INBOX/spam)
	docker cp "`pwd`/test/config/sieve/dovecot.sieve" mail:/var/mail/localhost.localdomain/user1/.dovecot.sieve
	docker exec mail /bin/sh -c "maildirmake.dovecot /var/mail/localhost.localdomain/user1/.INBOX.spam"
	docker exec mail /bin/sh -c "chown 5000:5000 -R /var/mail/localhost.localdomain/user1/.INBOX.spam"
	# Sending test mails
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-spam.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/amavis-virus.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-external.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-alias-local.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user-and-cc-local-alias.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-regexp-alias-external.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-regexp-alias-local.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-catchall-local.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/sieve-spam-folder.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/non-existing-user.txt"
	# Wait for mails to be analyzed
	sleep 10

tests:
	# Start tests
	./test/bats/bats test/tests.bats

clean:
	# Remove running test containers
	-docker rm -f \
		mail \
		mail_pop3 \
		mail_smtponly \
		mail_fail2ban \
		mail_fetchmail \
		fail-auth-mailer \
		mail_disabled_clamav_spamassassin \
		mail_manual_ssl \
		ldap_for_mail \
		mail_with_ldap

	@if [ -f config/postfix-accounts.cf.bak ]; then\
		rm -f config/postfix-accounts.cf ;\
		mv config/postfix-accounts.cf.bak config/postfix-accounts.cf ;\
	fi
	-sudo rm -rf test/onedir \
		test/config/empty \
		test/config/without-accounts \
		test/config/without-virtual
