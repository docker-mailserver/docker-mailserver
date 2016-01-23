NAME = tvial/docker-mailserver
VERSION = $(TRAVIS_BUILD_ID)

all: build run prepare fixtures tests

build:
	docker build --no-cache -t $(NAME):$(VERSION) . 

run:
	# Copy test files
	cp test/accounts.cf postfix/
	cp test/virtual postfix/
	# Run containers
	docker run -d --name mail -v "`pwd`/postfix":/tmp/postfix -v "`pwd`/spamassassin":/tmp/spamassassin -v "`pwd`/test":/tmp/test -h mail.my-domain.com -t $(NAME):$(VERSION)
	docker run -d --name mail_pop3 -v "`pwd`/postfix":/tmp/postfix -v "`pwd`/spamassassin":/tmp/spamassassin -v "`pwd`/test":/tmp/test -e ENABLE_POP3=1 -h mail.my-domain.com -t $(NAME):$(VERSION)
	sleep 25

prepare:
	# Reinitialize logs 
	docker exec mail /bin/sh -c 'echo "" > /var/log/mail.log'
	docker exec mail_pop3 /bin/sh -c 'echo "" > /var/log/mail.log'

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
	/bin/bash ./test/test.sh

clean:
	# Get default files back
	git checkout postfix/accounts.cf postfix/virtual
