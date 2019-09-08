# docker-mailserver

[![Build Status](https://travis-ci.org/tomav/docker-mailserver.svg?branch=master)](https://travis-ci.org/tomav/docker-mailserver) [![Docker Pulls](https://img.shields.io/docker/pulls/tvial/docker-mailserver.svg)](https://hub.docker.com/r/tvial/docker-mailserver/) [![Docker layers](https://images.microbadger.com/badges/image/tvial/docker-mailserver.svg)](https://microbadger.com/images/tvial/docker-mailserver) [![Github Stars](https://img.shields.io/github/stars/tomav/docker-mailserver.svg?label=github%20%E2%98%85)](https://github.com/tomav/docker-mailserver/) [![Github Stars](https://img.shields.io/github/contributors/tomav/docker-mailserver.svg)](https://github.com/tomav/docker-mailserver/) [![Github Forks](https://img.shields.io/github/forks/tomav/docker-mailserver.svg?label=github%20forks)](https://github.com/tomav/docker-mailserver/) [![Gitter](https://img.shields.io/gitter/room/tomav/docker-mailserver.svg)](https://gitter.im/tomav/docker-mailserver)


A fullstack but simple mail server (smtp, imap, antispam, antivirus...).
Only configuration files, no SQL database. Keep it simple and versioned.
Easy to deploy and upgrade.

Includes:

- [Postfix](http://www.postfix.org) with smtp or ldap auth
- [Dovecot](https://www.dovecot.org) for sasl, imap (and optional pop3) with ssl support, with ldap auth
  - Dovecot is installed from the [Dovecot Community Repo](https://wiki2.dovecot.org/PrebuiltBinaries)
- saslauthd with ldap auth
- [Amavis](https://www.amavis.org/)
- [Spamassasin](http://spamassassin.apache.org/) supporting custom rules
- [ClamAV](https://www.clamav.net/) with automatic updates
- [OpenDKIM](http://www.opendkim.org)
- [OpenDMARC](https://github.com/trusteddomainproject/OpenDMARC)
- [Fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [Fetchmail](http://www.fetchmail.info/fetchmail-man.html)
- [Postscreen](http://www.postfix.org/POSTSCREEN_README.html)
- [Postgrey](https://postgrey.schweikert.ch/)
- basic [Sieve support](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters) using dovecot
- [LetsEncrypt](https://letsencrypt.org/) and self-signed certificates
- [Setup script](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh) to easily configure and maintain your mailserver
- persistent data and state (but think about backups!)
- [Integration tests](https://travis-ci.org/tomav/docker-mailserver)
- [Automated builds on docker hub](https://hub.docker.com/r/tvial/docker-mailserver/)

Why I created this image: [Simple mail server with Docker](http://tvi.al/simple-mail-server-with-docker/)

Before you open an issue, please have a look this `README`, the [Wiki](https://github.com/tomav/docker-mailserver/wiki/) and Postfix/Dovecot documentation.

## Requirements
#### Exposed ports
Open the ports you need:
* 25 receiving email from other mailservers
* 465 SSL Client email submission
* 587 TLS Client email submission
* 143 StartTLS IMAP client
* 993 TLS/SSL IMAP client
* 110 POP3 client
* 995 TLS/SSL POP3 client

Note: Many ISP providers and cloud computation providers block port 25 (usually outgoing traffic), making it impossible to send emails to other mailservers. Before you start, make sure that port 25 is usable. You can test this by
```
$ telnet smtp.gmail.com 25
Trying 64.233.167.108...
Connected to gmail-smtp-msa.l.google.com.
Escape character is '^]'
```

Recommended:
- 1 CPU
- 1GB RAM

Minimum:
- 1 CPU
- 512MB RAM

**Note:** You'll need to deactivate some services like ClamAV to be able to run on a host with 512MB of RAM.

## Basic Usage

#### Get latest image

    docker pull tvial/docker-mailserver:latest

#### Get the tools

Download the docker-compose.yml, the .env and the setup.sh files:

    curl -o setup.sh https://raw.githubusercontent.com/tomav/docker-mailserver/master/setup.sh; chmod a+x ./setup.sh

    curl -o docker-compose.yml https://raw.githubusercontent.com/tomav/docker-mailserver/master/docker-compose.yml.dist

    curl -o .env https://raw.githubusercontent.com/tomav/docker-mailserver/master/.env.dist

#### Create a docker-compose environment

- The `.env` file contains the default environmental variables and their explanations. You can also find them in the more readable file [ENV.MD](ENV.MD). These variables will be passed to `docker-compose.yml` during running. You can change these variables in `docker-compose.yml`.
- Install [docker-compose](https://docs.docker.com/compose/) in the version `1.7` or higher.

#### Create your mail accounts (at least one account)

    ./setup.sh email add <user@domain> [<password>]

#### Generate DKIM keys

    ./setup.sh config dkim

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opendkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone if you are running your own DNS server. Or, go to your DNS provider website and use the content to create a record (or something similar):
- Record type: `TXT`
- Main record: `mail._domainkey`
- Record value: 
```
( "v=DKIM1; h=sha256; k=rsa; "
	  "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxG6b8/BgftnqyTnC30RvoEiN1BhCxP...+A0fA0SN/c9"
	  "bP7yYSOOfeRWWDmi4rpbdsorzrUcnfDLTm8oTlRETYc3pGaDXk3kuVnJ4P5O9bxiCXR/Zs7t8/ywuBwcc..." )  ; ----- DKIM key mail for mydomain.org
```

#### Start Container
    docker-compose up -d mail

#### Restart and update the container if necessary

    docker-compose down
    docker pull tvial/docker-mailserver:latest
    docker-compose up -d mail

You're done!

And don't forget to have a look at the remaining functions of the `setup.sh` script

#### SPF/Forwarding Problems

If you got any problems with SPF and/or forwarding mails, give [SRS](https://github.com/roehling/postsrsd/blob/master/README.md) a try. You enable SRS by setting `ENABLE_SRS=1`. See the variable description for further information.

#### For informational purposes:

Your config folder will be mounted in `/tmp/docker-mailserver/`. To understand how things work on boot, please have a look at [start-mailserver.sh](https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh)

`restart: always` ensures that the mail server container (and ELK container when using the mail server together with ELK stack) is automatically restarted by Docker in cases like a Docker service or host restart or container exit.

## More Examples
You can find more examples with different use cases under folder [Examples](Examples).
