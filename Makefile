NAME = tvial/docker-mailserver

all: build run fixtures tests clean
all-no-build: run fixtures tests clean

build:
	docker build --no-cache -t $(NAME) . 

run:
	# Copy test files
	cp test/accounts.cf postfix/
	cp test/virtual postfix/
	# Run containers
	docker run -d --name mail \
		-v "`pwd`/postfix":/tmp/postfix \
		-v "`pwd`/spamassassin":/tmp/spamassassin \
		-v "`pwd`/test":/tmp/test \
		-e SA_TAG=1.0 \
		-e SA_TAG2=2.0 \
		-e SA_KILL=3.0 \
		-h mail.my-domain.com -t $(NAME)
	docker run -d --name mail_pop3 \
		-v "`pwd`/postfix":/tmp/postfix \
		-v "`pwd`/spamassassin":/tmp/spamassassin \
		-v "`pwd`/test":/tmp/test \
		-e ENABLE_POP3=1 \
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
	sleep 10

tests:
	# Start tests
	./test/bats/bats test/tests.bats

clean:
	# Get default files back
	git checkout postfix/accounts.cf postfix/virtual
	# Remove running test containers
	docker rm -f mail mail_pop3