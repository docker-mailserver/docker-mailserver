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
- you should use a data volume container for `/var/mail` for data persistence
- email login are full email address (`username1@my-domain.com`)
- user accounts are managed in `./postfix/accounts.cf`
- aliases and fowards/redirects are managed in `./postfix/virtual`
- antispam are rules are managed in `./spamassassin/rules.cf`
- files must be mounted to `/tmp` in your container (see `docker-compose.yml` template)
- ssl is strongly recommended, you can provide a specific certificate (csr/key files), see below

## installation

	docker pull tvial/docker-mailserver

## build

	docker build -t tvial/docker-mailserver .

## run

	docker run --name mail -v "$(pwd)/postfix":/tmp/postfix -v "$(pwd)/spamassassin":/tmp/spamassassin -p "25:25" -p "143:143" -p "587:587" -p "993:993" -h mail.my-domain.com -t tvial/docker-mailserver

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
	  volumes:
	  - ./spamassassin:/tmp/spamassassin/
	  - ./postfix:/tmp/postfix/

Volumes allow to:

- Insert custom antispam rules
- Manage mail users, passwords and aliases

# usage

	docker-compose up -d mail

# configure ssl

## generate ssl certificate

You can easily generate en SSL certificate by using the following command:

	docker run -ti --rm -v "$(pwd)"/postfix/ssl:/ssl -h mail.my-domain.com -t tvial/docker-mailserver generate-ssl-certificate

	# Press enter
	# Enter a password when needed
	# Fill information like Country, Organisation name
	# Fill "mail.my-domain.com" as FQDN
	# Don't fill extras
	# Enter same password when needed
	# Sign the certificate? [y/n]:y
	# 1 out of 1 certificate requests certified, commit? [y/n]y

	# will generate:
	# postfix/ssl/mail.my-domain.com-key.pem (used in postfix)
	# postfix/ssl/mail.my-domain.com-req.pem
	# postfix/ssl/mail.my-domain.com-cert.pem (used in postfix)
	# postfix/ssl/mail.my-domain.com-combined.pem (used for courier)

Note that the certificate will be generate for the container `fqdn`, that is passed as `-h` argument.

## configure ssl certificate (convention over configuration)

If a matching certificate (with `.key` and `.csr` files) is found in `postfix/ssl`, it will be automatically configured in postfix. You just have to place `mail.my-domain.com.key` and `mail.my-domain.com.csr` for domain `mail.my-domain.com` in `postfix/ssl` folder.

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
