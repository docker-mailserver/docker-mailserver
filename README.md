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
- do not add whitespace in `$docker_mail_users` or `$docker_mail_aliases`

## installation

	docker pull tvial/docker-mailserver

## build

	docker build -t tvial/docker-mailserver .

## run

	docker run -p "25:25" -p "143:143" -p "587:587" -p "993:993" -e docker_mail_users="username1@my-domain.com|username1password" -h mail.my-domain.com -e docker_mail_domain=my-domain.com -t tvial/docker-mailserver

## docker-compose template (recommended)

	mail:
	  image: tvial/docker-mailserver
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
	    # format is user@domain.tld|list,of,aliases,comma,separated
	    docker_mail_aliases:
	      - "username1@my-domain.com|alias1,alias2,alias3"
	      - "username2@my-domain.com|alias4"

# todo

Things to do or to improve are stored on [Github](https://github.com/tomav/docker-mailserver/issues), some open by myself.
Feel free to improve this docker image.

# wanna help?

Fork, improve and PR. ;-)