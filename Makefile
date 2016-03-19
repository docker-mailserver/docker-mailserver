NAME = tvial/docker-mailserver

all: build run fixtures tests clean
all-no-build: run fixtures tests clean

build:
	docker build --no-cache -t $(NAME) . 

run:
	# Run containers
	docker run -d --name mail \
		-v "`pwd`/test/postfix":/tmp/postfix \
		-v "`pwd`/test/spamassassin":/tmp/spamassassin \
		-v "`pwd`/test":/tmp/test \
		-e SA_TAG=1.0 \
		-e SA_TAG2=2.0 \
		-e SA_KILL=3.0 \
		-e SASL_PASSWD=testing \
		-h mail.my-domain.com -t $(NAME)
	docker run -d --name mail_pop3 \
		-v "`pwd`/test/postfix":/tmp/postfix \
		-v "`pwd`/test/spamassassin":/tmp/spamassassin \
		-v "`pwd`/test":/tmp/test \
		-e ENABLE_POP3=1 \
		-h mail.my-domain.com -t $(NAME)
	docker run -d --name mail_smtponly \
		-v "`pwd`/test/postfix":/tmp/postfix \
		-v "`pwd`/test/spamassassin":/tmp/spamassassin \
		-v "`pwd`/test":/tmp/test \
		-e SMTP_ONLY=1 \
		-h mail.my-domain.com -t $(NAME)
	# Wait for containers to fully start
	sleep 60

fixtures:
	# Sending test mails
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/email-templates/amavis-spam.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/email-templates/amavis-virus.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/email-templates/existing-alias-external.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/email-templates/existing-alias-local.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/email-templates/existing-user.txt"
	docker exec mail /bin/sh -c "nc 0.0.0.0 25 < /tmp/test/email-templates/non-existing-user.txt"
	# Wait for mails to be analyzed
	sleep 30

tests:
	# Start tests
	./test/bats/bats test/tests.bats

clean:
	# Remove running test containers
	docker rm -f mail mail_pop3 mail_smtponly
