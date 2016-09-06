NAME = tvial/docker-mailserver:testing

all: build-no-cache generate-accounts run fixtures tests clean
all-fast: build generate-accounts run fixtures tests clean
no-build: generate-accounts run fixtures tests clean

build-no-cache:
	docker build --no-cache -t $(NAME) .

build:
	docker build -t $(NAME) .

generate-accounts:
	docker run --rm -e MAIL_USER=user1@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' > test/config/postfix-accounts.cf
	docker run --rm -e MAIL_USER=user2@otherdomain.tld -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf

run:
	# Run containers
	docker run -d --name mail \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-v "`pwd`/test/onedir":/var/mail-state \
		-e SA_TAG=1.0 \
		-e SA_TAG2=2.0 \
		-e SA_KILL=3.0 \
		-e SASL_PASSWD="external-domain.com username:password" \
		-e ENABLE_MANAGESIEVE=1 \
		-e ONE_DIR=1 \
		-e PERMIT_DOCKER=host\
		-h mail.my-domain.com -t $(NAME)
	sleep 20
	docker run -d --name mail_pop3 \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-v "`pwd`/test/config/letsencrypt":/etc/letsencrypt/live \
		-e ENABLE_POP3=1 \
		-e SSL_TYPE=letsencrypt \
		-h mail.my-domain.com -t $(NAME)
	sleep 20
	docker run -d --name mail_smtponly \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e SMTP_ONLY=1 \
		-e PERMIT_DOCKER=network\
		-h mail.my-domain.com -t $(NAME)
	sleep 20
	docker run -d --name mail_fail2ban \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_FAIL2BAN=1 \
		--cap-add=NET_ADMIN \
		-h mail.my-domain.com -t $(NAME)
	sleep 20
	docker run -d --name mail_fetchmail \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e ENABLE_FETCHMAIL=1 \
		--cap-add=NET_ADMIN \
		-h mail.my-domain.com -t $(NAME)
	sleep 20
	docker run -d --name mail_disabled_amavis \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e DISABLE_AMAVIS=1 \
		-h mail.my-domain.com -t $(NAME)
	sleep 20
	docker run -d --name mail_disabled_clamav \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e DISABLE_CLAMAV=1 \
		-h mail.my-domain.com -t $(NAME)
	docker run -d --name mail_manual_ssl \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver-test \
		-e SSL_TYPE=manual \
		-e SSL_CERT_PATH=/tmp/docker-mailserver/letsencrypt/mail.my-domain.com/fullchain.pem \
		-e SSL_KEY_PATH=/tmp/docker-mailserver/letsencrypt/mail.my-domain.com/privkey.pem \
		-h mail.my-domain.com -t $(NAME)
	# Wait for containers to fully start
	sleep 20

fixtures:
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
	docker rm -f mail mail_pop3 mail_smtponly mail_fail2ban mail_fetchmail fail-auth-mailer mail_disabled_amavis mail_disabled_clamav mail_manual_ssl
