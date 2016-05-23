# docker-mailserver [![Build Status](https://travis-ci.org/tve/docker-mailserver.svg?branch=master)](https://travis-ci.org/tve/docker-mailserver)

This is a fork of https://github.com/tomav/docker-mailserver with some additional features:

### Sending outbound mail via Amazon SES

Instead of letting postfix deliver mail directly it is possible to forward outgoing email
through Amazon SES (Simple Email Service). To enable this feature, define the following two
environment variables in the `docker-compose.yml` with the appropriate values for your AWS SES
subscription (the values for `AWS_SES_USERPASS` are the "SMTP username" and "SMTP password"
provided when yuo create SMTP credentials for SES):
```
    environment:
    - AWS_SES_HOST=email-smtp.us-east-1.amazonaws.com
    - AWS_SES_USERPASS=AKIAXXXXXXXXXXXXXXXX:kqXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Configuring regexp aliases

Additional regexp aliases can be configured by placing them into `config/postfix-regexp.cf`.
The regexp aliases get evaluated after the virtual aliases (`postfix-cirtual.cf`). For example,
the following `config/postfix-regexp.cf` causes all email to test users to be delivered
to `qa@example.com`:
```
/^test[0-9][0-9]*@example.com/ qa@example.com
```

## Overview

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
- basic [sieve support](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters) using dovecot
- [LetsEncrypt](https://letsencrypt.org/) and self-signed certificates
- [integration tests](https://travis-ci.org/tomav/docker-mailserver)
- [automated builds on docker hub](https://hub.docker.com/r/tvial/docker-mailserver/)

Why I created this image: [Simple mail server with Docker](http://tvi.al/simple-mail-server-with-docker/)

Before you open an issue, please have a look this `README`, the [Wiki](https://github.com/tomav/docker-mailserver/wiki/) and Postfix/Dovecot documentation.

## Usage

#### Get latest image
 
    docker pull tvial/docker-mailserver:latest

#### Create a `docker-compose.yml`

Adapt this file with your FQDN.

    version: '2'

    services:
      mail:
        image: tvial/docker-mailserver:latest
        # build: .
        hostname: mail
        domainname: domain.com
        container_name: mail
        ports:
        - "25:25"
        - "143:143"
        - "587:587"
        - "993:993"
        volumes:
        - maildata:/var/mail
        - ./config/:/tmp/docker-mailserver/

    volumes:
      maildata:
        driver: local

#### Create your mail accounts

Don't forget to adapt MAIL_USER and MAIL_PASS to your needs

    mkdir -p config
    docker run --rm \
      -e MAIL_USER=user1@domain.tld \
      -e MAIL_PASS=mypassword \
      -ti tvial/docker-mailserver:latest \
      /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s CRAM-MD5 -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf

#### Generate DKIM keys 

    docker run --rm \
      -v "$(pwd)/config":/tmp/docker-mailserver \
      -ti tvial/docker-mailserver:latest generate-dkim-config

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opedkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone.

#### Start the container

    docker-compose up -d mail

You're done!

## Environment variables

Please check [how the container starts](https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh) to understand what's expected.

Value in **bold** is the default value.

##### ENABLE_POP3

  - **empty** => POP3 service disabled
  - 1 => Enables POP3 service

##### ENABLE_FAIL2BAN

  - **empty** => fail2ban service disabled
  - 1 => Enables fail2ban service

If you enable Fail2Ban, don't forget to add the following lines to your `docker-compose.yml`:

    cap_add:
      - NET_ADMIN

Otherwise, `iptables` won't be able to ban IPs.

##### ENABLE_MANAGESIEVE

  - **empty** => Managesieve service disabled
  - 1 => Enables Managesieve on port 4190

##### SA_TAG

  - **2.0** => add spam info headers if at, or above that level

##### SA_TAG2

  - **6.31** => add 'spam detected' headers at that level

##### SA_KILL

  - **6.31** => triggers spam evasive actions

##### SASL_PASSWD

  - **empty** => No sasl_passwd will be created
  - string => `/etc/postfix/sasl_passwd` will be created with the string as password

##### SMTP_ONLY

  - **empty** => all daemons start
  - 1 => only launch postfix smtp

##### SSL_TYPE

  - **empty** => SSL disabled
  - letsencrypt => Enables Let's Encrypt certificates
  - custom => Enables custom certificates
  - self-signed => Enables self-signed certificates

Please read [the SSL page in the wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-SSL) for more information.


