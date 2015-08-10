# docker-mailserver

A fullstack but simple mail server (smtp, imap, antispam, antivirus...).  
Only configuration files, no SQL database. Keep it simple and versioned.  
Easy to deploy and upgrade.  

Includes:

- postfix with smtp auth
- courier-imap with ssl support
- amavis
- spamassasin
- clamav with automatic updates

Additional informations:

- only config files, no *sql database required
- mails are stored in `/var/mail/${domain}/${username}`
- email login are full email address (`username1@my-domain.com`)
- ssl is strongly recommended
- user accounts are managed in `./postfix/accounts.cf`
- aliases and fowards/redirects are managed in `./postfix/virtual`
- antispam are rules are managed in `./spamassassin/rules.cf`
- files must be mounted to `/tmp` in your container (see `docker-compose.yml` template)

## installation

	docker pull tvial/docker-mailserver

## build

	docker build -t tvial/docker-mailserver .

## run

	docker run -p "25:25" -p "143:143" -p "587:587" -p "993:993" -e docker_mail_domain=my-domain.com -t tvial/docker-mailserver

## docker-compose template (recommended)

	mail:
	  # image: tvial/docker-mailserver
	  build: .
	  hostname: mail
	  domainname: my-domain.com
	  ports:
	  - "25:25"
	  - "143:143"
	  - "587:587"
	  - "993:993"
	  environment:
	    docker_mail_domain: "my-domain.com"
	  volumes:
	  - ./spamassassin:/tmp/spamassassin/:ro
	  - ./postfix:/tmp/postfix/:ro

Volumes allow to:

- Insert custom antispam rules
- Manage mail users, passwords and aliases

# usage

	docker-compose up -d mail

# client configuration

	# imap
	username:  				<username1@my-domain.com>
	password:  				<username1password>
	server:    				<your-server-ip-or-hostname>
	imap port: 				143 or 993 with ssl (recommended)
	imap path prefix:		INBOX
	auth method:			md5 challenge-response

	# smtp
	smtp port:				25 or 587 with ssl (recommended)
	username:  				<username1@my-domain.com>
	password:  				<username1password>
	auth method:			md5 challenge-response

# todo

Things to do or to improve are stored on [Github](https://github.com/tomav/docker-mailserver/issues), some open by myself.
Feel free to improve this docker image.

# wanna help?

Fork, improve and PR. ;-)
