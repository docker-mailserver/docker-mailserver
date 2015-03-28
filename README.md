# docker-mailserver

A fullstack but simple mail  server (smtp, imap, antispam, antivirus...)

Includes:
- postfix
- courier-imap
- spamassasin
- clamav
- amavis

Only config files, no *sql database required.

## installation

	docker pull tvial/docker-mailserver

## build

	docker build -t tvial/docker-mailserver .

## docker-compose template

	mail:
	  build: .
	  hostname: mail
	  domainname: my-domain.com
	  ports:
	  - "25:25"
	  - "143:143"
	  - "587:587"
	  - "993:993"
	  volumes:
	    - ./configs/courier:/etc/courier
	    - ./configs/postfix:/etc/postfix
	    - ./configs/spamassassin:/etc/spamassassin
	  environment:
	    docker_mail_domain: "my-domain.com"
	    # format is user@domain.tld|clear_password
	    docker_mail_users:
	      - "username1@my-domain.com|username1password"
	      - "username2@my-domain.com|username2password"

# wanna help?

Fork, improve and PR. ;-)