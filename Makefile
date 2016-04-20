BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
NAME = tvial/docker-mailserver:$(BRANCH)

all: build-no-cache run fixtures tests clean
all-fast: build run fixtures tests clean
no-build: run fixtures tests clean

build-no-cache:
	docker build --no-cache -t $(NAME) .

build:
	docker build -t $(NAME) .

run:
	# Run containers
	docker run -d --name mail \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/config/test-opendkim":/tmp/docker-mailserver/opendkim \
		-v "`pwd`/test":/tmp/docker-mailserver/test \
		-e SA_TAG=1.0 \
		-e SA_TAG2=2.0 \
		-e SA_KILL=3.0 \
		-e SASL_PASSWD=testing \
		-h mail.my-domain.com -t $(NAME)
	sleep 15
	docker run -d --name mail_pop3 \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver/test \
		-e ENABLE_POP3=1 \
		-h mail.my-domain.com -t $(NAME)
	sleep 15
	docker run -d --name mail_smtponly \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver/test \
		-e SMTP_ONLY=1 \
		-h mail.my-domain.com -t $(NAME)
	sleep 15
	docker run -d --name mail_fail2ban \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test":/tmp/docker-mailserver/test \
		-e ENABLE_FAIL2BAN=1 \
		-h mail.my-domain.com -t $(NAME)
	# Wait for containers to fully start
	sleep 15

fixtures:
	# Sending test mails
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver/test/email-templates/amavis-spam.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver/test/email-templates/amavis-virus.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver/test/email-templates/existing-alias-external.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver/test/email-templates/existing-alias-local.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver/test/email-templates/existing-user.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/docker-mailserver/test/email-templates/non-existing-user.txt"
	# Wait for mails to be analyzed
	sleep 10

tests:
	# Start tests
	./test/bats/bats test/tests.bats

clean:
	# Remove running test containers
	docker rm -f mail mail_pop3 mail_smtponly mail_fail2ban fail-auth-mailer
	rm -rf config/opendkim config/test-opendkim config/tmp
