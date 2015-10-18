NAME = tvial/docker-mailserver
VERSION = travis

all: build run prepare fixtures tests

build:
	docker build --no-cache -t $(NAME):$(VERSION) . 

run:
	# Copy test files
	cp test/accounts.cf postfix/
	cp test/virtual postfix/
	# Run container
	docker run -d --name mail -v "`pwd`/postfix":/tmp/postfix -v "`pwd`/spamassassin":/tmp/spamassassin -h mail.my-domain.com -t $(NAME):$(VERSION)
	sleep 15

prepare:
	# Reinitialize logs 
	docker exec mail /bin/sh -c 'echo "" > /var/log/mail.log'

fixtures:
	docker exec mail /bin/sh -c 'echo "This is a test mail" | mail -s "TEST-001" user@localhost.localdomain'
	docker exec mail /bin/sh -c 'echo "This is a test mail" | mail -s "TEST-002" nouser@localhost.localdomain'
	docker exec mail /bin/sh -c 'echo "This is a test mail" | mail -s "TEST-003" alias1@localhost.localdomain'
	docker exec mail /bin/sh -c 'echo "This is a test mail" | mail -s "TEST-004" alias2@localhost.localdomain'

tests:
	# Start tests
	./test/test.sh
