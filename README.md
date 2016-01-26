# docker-mailserver

[![Build Status](https://travis-ci.org/tomav/docker-mailserver.svg?branch=master)](https://travis-ci.org/tomav/docker-mailserver)

A fullstack but simple mail server (smtp, imap, antispam, antivirus...).  
Only configuration files, no SQL database. Keep it simple and versioned.  
Easy to deploy and upgrade.  

Includes:

- postfix with smtp auth
- courier-imap with ssl support
- amavis
- spamassasin
- clamav with automatic updates
- opendkim

Why I created this image: [Simple mail server with Docker](http://tvi.al/simple-mail-server-with-docker/)

## informations:

- only config files, no *sql database required
- mails are stored in `/var/mail/${domain}/${username}`
- you should use a data volume container for `/var/mail` for data persistence
- email login are full email address (`username1@my-domain.com`)
- user accounts are managed in `./postfix/accounts.cf`
- aliases and fowards/redirects are managed in `./postfix/virtual`
- antispam rules are managed in `./spamassassin/rules.cf`
- files must be mounted to `/tmp` in your container (see `docker-compose.yml` template)
- ssl is strongly recommended, read [SSL.md](SSL.md) to use LetsEncrypt or Self-Signed Certificates
- [includes integration tests](https://travis-ci.org/tomav/docker-mailserver) 
- [builds automated on docker hub](https://hub.docker.com/r/tvial/docker-mailserver/)
- dkim public key will be echoed to log. If you have your previous configuration, you can mount volume with it `-v "$(pwd)/opendkim":/etc/opendkim"`

## installation

	docker pull tvial/docker-mailserver

## build

	docker build -t tvial/docker-mailserver .

## run

	docker run --name mail \
    -v "$(pwd)/postfix":/tmp/postfix \
    -v "$(pwd)/spamassassin":/tmp/spamassassin \
    -v "$(pwd)/letsencrypt/etc":/etc/letsencrypt \
    -p "25:25" -p "143:143" -p "587:587" -p "993:993" \
    -e DMS_SSL=letsencrypt \
    -h mail.domain.com \
    -t tvial/docker-mailserver

## docker-compose template (recommended)

    mail:
      image: tvial/docker-mailserver
      hostname: mail
      domainname: domain.com
      ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
      volumes:
      - ./spamassassin:/tmp/spamassassin/
      - ./postfix:/tmp/postfix/
      - ./letsencrypt/etc:/etc/letsencrypt
      environment:
      - DMS_SSL=letsencrypt

Volumes allow to:

- Insert custom antispam rules
- Manage mail users, passwords and aliases
- Manage SSL certificates

# usage

	docker-compose up -d mail

# client configuration

    # imap
    username:         <username1@my-domain.com>
    password:         <username1password>
    server:           <your-server-ip-or-hostname>
    imap port:        143 or 993 with ssl (recommended)
    imap path prefix:   INBOX
    auth method:      md5 challenge-response

    # smtp
    smtp port:        25 or 587 with ssl (recommended)
    username:         <username1@my-domain.com>
    password:         <username1password>
    auth method:      md5 challenge-response

# backups

Assuming that you use `docker-compose` and a data volume container named `maildata`, you can backup your user mails like this:

    docker run --rm \
    --volumes-from maildata_1 \
    -v "$(pwd)":/backups \
    -ti tvial/docker-mailserver \
    tar cvzf /backups/docker-mailserver-`date +%y%m%d-%H%M%S`.tgz /var/mail

# todo

Things to do or to improve are stored on [Github](https://github.com/tomav/docker-mailserver/issues), some open by myself.
Feel free to improve this docker image.

# wanna help?

Fork, improve, add tests and PR. ;-)
