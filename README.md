# docker-mailserver

```
#
# CURRENTLY IN BETA
#
```

[![Build Status](https://travis-ci.org/tomav/docker-mailserver.svg?branch=v2)](https://travis-ci.org/tomav/docker-mailserver)

A fullstack but simple mail server (smtp, imap, antispam, antivirus...).  
Only configuration files, no SQL database. Keep it simple and versioned.  
Easy to deploy and upgrade.  

Includes:

- postfix with smtp auth
- dovecot for sasl, imap (and optional pop3) with ssl support
- amavis
- spamassasin supporting custom rules
- clamav with automatic updates
- opendkim
- opendmarc 
- fail2ban
- [LetsEncrypt](https://letsencrypt.org/) and self-signed certificates
- [integration tests](https://travis-ci.org/tomav/docker-mailserver) 
- [automated builds on docker hub](https://hub.docker.com/r/tvial/docker-mailserver/)

Why I created this image: [Simple mail server with Docker](http://tvi.al/simple-mail-server-with-docker/)

Before you open an issue, please have a look this `README`, the [FAQ](https://github.com/tomav/docker-mailserver/wiki/FAQ) and Postfix/Dovecot documentation. 

## Project architecture

    ├── config                    # User: personal configurations
    ├── docker-compose.yml.dist   # User: 'docker-compose.yml' example
    ├── target                    # Developer: default server configurations
    └── test                      # Developer: integration tests

## Basic usage

    # get v2 image
    docker pull tvial/docker-mailserver:v2

    # create a "docker-compose.yml" file containing:  
    mail:
      image: tvial/docker-mailserver:v2
      hostname: mail
      domainname: domain.com
      # your FQDN will be 'mail.domain.com'
      ports:
      - "25:v25"
      - "143:143"
      - "587:587"
      - "993:993"
      volumes:
      - ./config/:/tmp/docker-mailserver/

    # Create your first mail account
    # Don't forget to adapt MAIL_USER and MAIL_PASS to your needs
    mkdir -p config
    docker run --rm \
      -e MAIL_USER=username@domain.tld \
      -e MAIL_PASS=mypassword \
      -ti tvial/docker-mailserver:v2 \
      /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s CRAM-MD5 -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf

    # start the container
  	docker-compose up -d mail

You're done!

## Managing users and aliases

### Users

As you've seen above, users are managed in `config/postfix-accounts.cf`.  
Just add the full email address and its encrypted password separated by a pipe.  

Example:

    user1@domain.tld|{SCHEME}mypassword-encrypted
    user2@otherdomain.tld|{SCHEME}myotherpassword-encrypted

To generate the password you could run for example the following:

    docker run --rm -ti tvial/docker-mailserver:v2 doveadm pw -s CRAM-MD5 -u user1@domain.tld

You will be asked for a password (and for a confirmation of the password). Just copy all the output string in the file `config/postfix-accounts.cf`.

    The `doveadm pw` command let you choose between several encryption schemes for the password.
    Use doveadm pw -l to get a list of the currently supported encryption schemes.

### Aliases

Please first read [Postfix documentation on virtual aliases](http://www.postfix.org/VIRTUAL_README.html#virtual_alias).

Aliases are managed in `config/postfix-virtual.cf`.  
An alias is a full email address that will be:
* delivered to an existing account in `config/postfix-accounts.cf`
* redirected to one or more other email adresses

Alias and target are space separated. 

Example:

    # Alias to existing account
    alias1@domain.tld user1@domain.tld

    # Forward to external email address
    alias2@domain.tld external@gmail.com

## Environment variables

* DMS_SSL
  * *empty* (default) => SSL disabled
  * letsencrypt => Enables Let's Encrypt certificates
  * self-signed => Enables self-signed certificates
* ENABLE_POP3
  * *empty* (default) => POP3 service disabled
  * 1 => Enables POP3 service
* SMTP_ONLY
  * *empty* (default) => courier daemons might start
  * *1 => do not launch any courier daemons (imap, pop3)
* SA_TAG
  * *2.0* (default) => add spam info headers if at, or above that level
* SA_TAG2
  * *6.31* (default) => add 'spam detected' headers at that level
* SA_KILL
  * *6.31* (default) => triggers spam evasive actions
* SASL_PASSWD
  * *empty* (default) => No sasl_passwd will be created
  * *string* => A /etc/postfix/sasl_passwd will be created with that content and postmap will be run on it
* ENABLE_FAIL2BAN
  * *empty* (default) => fail2ban service disabled
  * 1 => Enables fail2ban service

Please check [how the container starts](https://github.com/tomav/docker-mailserver/blob/v2/start-mailserver.sh) to understand what's expected.  

## OpenDKIM

You have prepared your mail accounts? Now you can generate DKIM keys using the following command:

    docker run --rm \
      -v "$(pwd)/config":/tmp/docker-mailserver \
      -ti tvial/docker-mailserver:v2 generate-dkim-config 

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opedkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone.

## SSL

Please read [the SSL page in the wiki](https://github.com/tomav/docker-mailserver/wiki/SSL) for more information.

## Todo

Things to do or to improve are stored on [Github](https://github.com/tomav/docker-mailserver/issues).
Feel free to improve this docker image.

## Contribute

- Fork
- Improve
- Add integration tests in `test/tests.bats`
- Build image and run tests using `make`  
- Document your improvements
- Commit, push and make a pull-request
