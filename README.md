# docker-mailserver

A fullstack but simple mail server (smtp, imap, antispam, antivirus...)

Includes:

- postfix with smtp auth
- courier-imap with ssl support
- amavis
- spamassasin
- clamav

Additional informations:

- only config files, no *sql database required
- mails are stored in `/var/mail/${domain}/${username}`
- email login are full email address (`username1@my-domain.com`)
- ssl is strongly recommended

## installation

	docker pull tvial/docker-mailserver

## build

	docker build -t tvial/docker-mailserver .

## docker-compose template

	mail:
	  build: .
	  # or use 'image: tvial/docker-mailserver'
	  hostname: mail
	  domainname: my-domain.com
	  ports:
	  - "25:25"
	  - "143:143"
	  - "587:587"
	  - "993:993"
	  environment:
	    docker_mail_domain: "my-domain.com"
	    # format is user@domain.tld|clear_password
	    docker_mail_users:
	      - "username1@my-domain.com|username1password"
	      - "username2@my-domain.com|username2password"

# wanna help?

Fork, improve and PR. ;-)