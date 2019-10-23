NAME = tvial/docker-mailserver:testing
VCS_REF := $(shell git rev-parse --short HEAD)
VCS_VERSION := $(shell git describe)

all: build backup generate-accounts run generate-accounts-after-run fixtures tests clean
no-build: backup generate-accounts run generate-accounts-after-run fixtures tests clean

build:
	docker build \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg VCS_VERSION=$(VCS_VERSION) \
		-t $(NAME) .

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

run:
	# Run containers
	docker run --rm -d --name mail \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-v "`pwd`/test/onedir":/var/mail-state \
		-e ENABLE_CLAMAV=1 \
		-e SPOOF_PROTECTION=1 \
		-e ENABLE_SPAMASSASSIN=1 \
		-e REPORT_RECIPIENT=user1@localhost.localdomain \
		-e REPORT_SENDER=report1@mail.my-domain.com \
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
	sleep 15
	docker run --rm -d --name mail_smtponly_without_config \
		-e SMTP_ONLY=1 \
		-e ENABLE_LDAP=1 \
		-e PERMIT_DOCKER=network \
		-e OVERRIDE_HOSTNAME=mail.mydomain.com \
		-t $(NAME)
	sleep 15
	docker run --rm -d --name mail_override_hostname \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e ENABLE_SRS=1 \
		-e OVERRIDE_HOSTNAME=mail.my-domain.com \
		-h unknown.domain.tld \
		-t $(NAME)
	sleep 15
	docker run --rm -d --name mail_domainname \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e ENABLE_SRS=1 \
		-e DOMAINNAME=my-domain.com \
		-h unknown.domain.tld \
		-t $(NAME)
	sleep 15
	docker run --rm -d --name mail_srs_domainname \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e ENABLE_SRS=1 \
		-e SRS_DOMAINNAME=srs.my-domain.com \
		-e DOMAINNAME=my-domain.com \
		-h unknown.domain.tld \
		-t $(NAME)
	sleep 15
	docker run --rm -d --name mail_disabled_clamav_spamassassin \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e ENABLE_CLAMAV=0 \
		-e ENABLE_SPAMASSASSIN=0 \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t $(NAME)
	sleep 15

generate-accounts-after-run:
	docker run --rm -e MAIL_USER=added@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf
	docker exec mail addmailuser pass@localhost.localdomain 'may be \a `p^a.*ssword'

	sleep 10

fixtures:
	# Setup sieve & create filtering folder (INBOX/spam)
	docker cp "`pwd`/test/config/sieve/dovecot.sieve" mail:/var/mail/localhost.localdomain/user1/.dovecot.sieve
	sleep 30
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
	docker exec mail_disabled_clamav_spamassassin /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
	docker exec mail /bin/sh -c "sendmail root < /tmp/docker-mailserver-test/email-templates/root-email.txt"
	# postfix virtual transport lmtp
	docker exec mail_override_hostname /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
	# Wait for mails to be analyzed
	sleep 80

tests:
	# Start tests
	./test/bats/bin/bats test/*.bats

.PHONY: ALWAYS_RUN

test/%.bats: ALWAYS_RUN
		./test/bats/bin/bats $@

lint:
	# List files which name starts with 'Dockerfile'
	# eg. Dockerfile, Dockerfile.build, etc.
	git ls-files --exclude='Dockerfile*' --ignored | xargs --max-lines=1 hadolint

clean:
	# Remove running and stopped test containers
	-docker ps -a | grep -E "docker-mailserver:testing|ldap_for_mail" | cut -f 1-1 -d ' ' | xargs --no-run-if-empty docker rm -f

	@if [ -d config.bak ]; then\
		rm -rf config ;\
		mv config.bak config ;\
	fi
	@if [ -d testconfig.bak ]; then\
		sudo rm -rf test/config ;\
		mv testconfig.bak test/config ;\
	fi
	-sudo rm -rf test/onedir test/alias test/relay test/config/dovecot-lmtp/userdb test/config/key* test/config/opendkim/keys/domain.tld/ test/config/opendkim/keys/example.com/ test/config/opendkim/keys/localdomain2.com/ test/config/postfix-aliases.cf test/config/postfix-receive-access.cf test/config/postfix-receive-access.cfe test/config/postfix-send-access.cf test/config/postfix-send-access.cfe test/config/relay-hosts/chksum test/config/relay-hosts/postfix-aliases.cf
