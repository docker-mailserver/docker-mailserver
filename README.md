# docker-mailserver

[![Build Status](https://travis-ci.org/tomav/docker-mailserver.svg?branch=master)](https://travis-ci.org/tomav/docker-mailserver) [![Docker Pulls](https://img.shields.io/docker/pulls/tvial/docker-mailserver.svg)](https://hub.docker.com/r/tvial/docker-mailserver/) [![Docker layers](https://images.microbadger.com/badges/image/tvial/docker-mailserver.svg)](https://microbadger.com/images/tvial/docker-mailserver) [![Github Stars](https://img.shields.io/github/stars/tomav/docker-mailserver.svg?label=github%20%E2%98%85)](https://github.com/tomav/docker-mailserver/) [![Github Stars](https://img.shields.io/github/contributors/tomav/docker-mailserver.svg)](https://github.com/tomav/docker-mailserver/) [![Github Forks](https://img.shields.io/github/forks/tomav/docker-mailserver.svg?label=github%20forks)](https://github.com/tomav/docker-mailserver/) [![Gitter](https://img.shields.io/gitter/room/tomav/docker-mailserver.svg)](https://gitter.im/tomav/docker-mailserver)


A fullstack but simple mail server (smtp, imap, antispam, antivirus...).
Only configuration files, no SQL database. Keep it simple and versioned.
Easy to deploy and upgrade.

Includes:

- postfix with smtp or ldap auth
- dovecot for sasl, imap (and optional pop3) with ssl support, with ldap auth
- saslauthd with ldap auth
- [amavis](https://www.amavis.org/)
- [spamassasin](http://spamassassin.apache.org/) supporting custom rules
- [clamav](https://www.clamav.net/) with automatic updates
- opendkim
- opendmarc
- [fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [fetchmail](http://www.fetchmail.info/fetchmail-man.html)
- [postscreen](http://www.postfix.org/POSTSCREEN_README.html)
- [postgrey](https://postgrey.schweikert.ch/)
- basic [sieve support](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters) using dovecot
- [LetsEncrypt](https://letsencrypt.org/) and self-signed certificates
- [setup script](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh) to easily configure and maintain your mailserver
- persistent data and state (but think about backups!)
- [integration tests](https://travis-ci.org/tomav/docker-mailserver)
- [automated builds on docker hub](https://hub.docker.com/r/tvial/docker-mailserver/)

Why I created this image: [Simple mail server with Docker](http://tvi.al/simple-mail-server-with-docker/)

Before you open an issue, please have a look this `README`, the [Wiki](https://github.com/tomav/docker-mailserver/wiki/) and Postfix/Dovecot documentation.

## Requirements

Recommended:
- 1 CPU
- 1GB RAM

Minimum:
- 1 CPU
- 512MB RAM

**Note:** You'll need to deactivate some services like ClamAV to be able to run on a host with 512MB of RAM.

## Usage

#### Get latest image

    docker pull tvial/docker-mailserver:latest

#### Get the tools

Download the docker-compose.yml, the .env and the setup.sh files:
    
    curl -o setup.sh https://raw.githubusercontent.com/tomav/docker-mailserver/master/setup.sh; chmod a+x ./setup.sh
    
    curl -o docker-compose.yml https://raw.githubusercontent.com/tomav/docker-mailserver/master/docker-compose.yml.dist
    
    curl -o .env https://raw.githubusercontent.com/tomav/docker-mailserver/master/.env.dist

#### Create a docker-compose environment

- Edit the `.env` to your liking. Adapt this file with your FQDN. 
- Install [docker-compose](https://docs.docker.com/compose/) in the version `1.6` or higher.

#### Create your mail accounts

    ./setup.sh email add <email> [<password>]

#### Generate DKIM keys

    ./setup.sh config dkim

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opendkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone.

#### Start the container

    docker-compose up -d mail

You're done!

And don't forget to have a look at the remaining functions of the `setup.sh` script

#### For informational purposes:

Your config folder will be mounted in `/tmp/docker-mailserver/`. To understand how things work on boot, please have a look at [start-mailserver.sh](https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh)

`restart: always` ensures that the mail server container (and ELK container when using the mail server together with ELK stack) is automatically restarted by Docker in cases like a Docker service or host restart or container exit.

##### Examples with just the relevant environmental variables:

```yaml
version: '2'

services:
  mail:
    image: tvial/docker-mailserver:latest
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
    - mailstate:/var/mail-state
    - ./config/:/tmp/docker-mailserver/
    environment:
    - ENABLE_SPAMASSASSIN=1
    - ENABLE_CLAMAV=1
    - ENABLE_FAIL2BAN=1
    - ENABLE_POSTGREY=1
    - ONE_DIR=1
    - DMS_DEBUG=0
    cap_add:
    - NET_ADMIN
    - SYS_PTRACE

volumes:
  maildata:
    driver: local
  mailstate:
    driver: local
```

__for ldap setup__:

```yaml
version: '2'

services:
  mail:
    image: tvial/docker-mailserver:latest
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
      - mailstate:/var/mail-state
      - ./config/:/tmp/docker-mailserver/
    environment:
      - ENABLE_SPAMASSASSIN=1
      - ENABLE_CLAMAV=1
      - ENABLE_FAIL2BAN=1
      - ENABLE_POSTGREY=1
      - ONE_DIR=1
      - DMS_DEBUG=0
      - ENABLE_LDAP=1
      - LDAP_SERVER_HOST=ldap # your ldap container/IP/ServerName
      - LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain
      - LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain
      - LDAP_BIND_PW=admin
      - LDAP_QUERY_FILTER_USER="(&(mail=%s)(mailEnabled=TRUE))"
      - LDAP_QUERY_FILTER_GROUP="(&(mailGroupMember=%s)(mailEnabled=TRUE))"
      - LDAP_QUERY_FILTER_ALIAS="(&(mailAlias=%s)(mailEnabled=TRUE))"
      - DOVECOT_PASS_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"
      - DOVECOT_USER_FILTER="(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"
      - ENABLE_SASLAUTHD=1
      - SASLAUTHD_MECHANISMS=ldap
      - SASLAUTHD_LDAP_SERVER=ldap
      - SASLAUTHD_LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain
      - SASLAUTHD_LDAP_PASSWORD=admin
      - SASLAUTHD_LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain
      - POSTMASTER_ADDRESS=postmaster@localhost.localdomain
    cap_add:
      - NET_ADMIN
      - SYS_PTRACE

volumes:
  maildata:
    driver: local
  mailstate:
    driver: local
```

# Environment variables

Please check [how the container starts](https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh) to understand what's expected. Also if an option doesn't work as documented here, check if you are running the latest image!

Value in **bold** is the default value.

## General

##### DMS_DEBUG

  - **0** => Debug disabled
  - 1 => Enables debug on startup

##### ENABLE_CLAMAV

  - **0** => Clamav is disabled
  - 1 => Clamav is enabled

##### ONE_DIR

  - **0** => state in default directories
  - 1 => consolidate all states into a single directory (`/var/mail-state`) to allow persistence using docker volumes

##### ENABLE_POP3

  - **empty** => POP3 service disabled
  - 1 => Enables POP3 service

##### ENABLE_FAIL2BAN

  - **0** => fail2ban service disabled
  - 1 => Enables fail2ban service

If you enable Fail2Ban, don't forget to add the following lines to your `docker-compose.yml`:

    cap_add:
      - NET_ADMIN

Otherwise, `iptables` won't be able to ban IPs.
##### SMTP_ONLY

  - **empty** => all daemons start
  - 1 => only launch postfix smtp

##### SSL_TYPE

  - **empty** => SSL disabled
  - letsencrypt => Enables Let's Encrypt certificates
  - custom => Enables custom certificates
  - manual => Let's you manually specify locations of your SSL certificates for non-standard cases
  - self-signed => Enables self-signed certificates

Please read [the SSL page in the wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-SSL) for more information.

##### PERMIT_DOCKER

Set different options for mynetworks option (can be overwrite in postfix-main.cf)
  - **empty** => localhost only
  - host => Add docker host (ipv4 only)
  - network => Add all docker containers (ipv4 only)

##### VIRUSMAILS_DELETE_DELAY

Set how many days a virusmail will stay on the server before being deleted
  - **empty** => 7 days


##### ENABLE_POSTFIX_VIRTUAL_TRANSPORT

This Option is activating the Usage of POSTFIX_DAGENT to specify a ltmp client different from default dovecot socket.

- **empty** => disabled
- 1 => enabled

##### POSTFIX_DAGENT

Enabled by ENABLE_POSTFIX_VIRTUAL_TRANSPORT. Specify the final delivery of postfix

- **empty**: fail
- `lmtp:unix:private/dovecot-lmtp` (use socket)
- `lmtps:inet:<host>:<port>` (secure lmtp with starttls, take a look at https://sys4.de/en/blog/2014/11/17/sicheres-lmtp-mit-starttls-in-dovecot/)
- `lmtp:<kopano-host>:2003` (use kopano as mailstore)
- etc.

##### ENABLE_MANAGESIEVE

  - **empty** => Managesieve service disabled
  - 1 => Enables Managesieve on port 4190

##### OVERRIDE_HOSTNAME

  - **empty** => uses the `hostname` command to get the mail server's canonical hostname
  - => Specify a fully-qualified domainname to serve mail for.  This is used for many of the config features so if you can't set your hostname (e.g. you're in a container platform that doesn't let you) specify it in this environment variable.

##### POSTMASTER_ADDRESS

  - **empty** => postmaster@domain.com
  - => Specify the postmaster address

##### POSTSCREEN_ACTION

  - **enforce** => Allow other tests to complete. Reject attempts to deliver mail with a 550 SMTP reply, and log the helo/sender/recipient information. Repeat this test the next time the client connects.
  - drop => Drop the connection immediately with a 521 SMTP reply. Repeat this test the next time the client connects.
  - ignore => Ignore the failure of this test. Allow other tests to complete. Repeat this test the next time the client connects. This option is useful for testing and collecting statistics without blocking mail.

## Spamassassin

##### ENABLE_SPAMASSASSIN

  - **0** => Spamassassin is disabled
  - 1 => Spamassassin is enabled

##### SA_TAG

  - **2.0** => add spam info headers if at, or above that level

Note: this spamassassin setting needs `ENABLE_SPAMASSASSIN=1`

##### SA_TAG2

  - **6.31** => add 'spam detected' headers at that level

Note: this spamassassin setting needs `ENABLE_SPAMASSASSIN=1`

##### SA_KILL

  - **6.31** => triggers spam evasive actions

Note: this spamassassin setting needs `ENABLE_SPAMASSASSIN=1`

##### SA_SPAM_SUBJECT

  - **\*\*\*SPAM\*\*\*** => add tag to subject if spam detected

Note: this spamassassin setting needs `ENABLE_SPAMASSASSIN=1`

## Fetchmail

##### ENABLE_FETCHMAIL
  - **0** => `fetchmail` disabled
  - 1 => `fetchmail` enabled

##### FETCHMAIL_POLL
  - **300** => `fetchmail` The number of seconds for the interval

## LDAP

##### ENABLE_LDAP

  - **empty** => LDAP authentification is disabled
  - 1 => LDAP authentification is enabled
  - NOTE:
    - A second container for the ldap service is necessary (e.g. [docker-openldap](https://github.com/osixia/docker-openldap))
    - For preparing the ldap server to use in combination with this continer [this](http://acidx.net/wordpress/2014/06/installing-a-mailserver-with-postfix-dovecot-sasl-ldap-roundcube/) article may be helpful

##### LDAP_START_TLS

  - **empty** => no
  - yes => LDAP over TLS enabled for Postfix

##### LDAP_SERVER_HOST

  - **empty** => mail.domain.com
  - => Specify the dns-name/ip-address where the ldap-server
  - NOTE: If you going to use the mailserver in combination with docker-compose you can set the service name here

##### LDAP_SEARCH_BASE

  - **empty** => ou=people,dc=domain,dc=com
  - => e.g. LDAP_SEARCH_BASE=dc=mydomain,dc=local

##### LDAP_BIND_DN

  - **empty** => cn=admin,dc=domain,dc=com
  - => take a look at examples of SASL_LDAP_BIND_DN

##### LDAP_BIND_PW

  - **empty** => admin
  - => Specify the password to bind against ldap

##### LDAP_QUERY_FILTER_USER

  - e.g. `"(&(mail=%s)(mailEnabled=TRUE))"`
  - => Specify how ldap should be asked for users

##### LDAP_QUERY_FILTER_GROUP

  - e.g. `"(&(mailGroupMember=%s)(mailEnabled=TRUE))"`
  - => Specify how ldap should be asked for groups

##### LDAP_QUERY_FILTER_ALIAS

  - e.g. `"(&(mailAlias=%s)(mailEnabled=TRUE))"`
  - => Specify how ldap should be asked for aliases

##### DOVECOT_TLS

  - **empty** => no
  - yes => LDAP over TLS enabled for Dovecot

## Dovecot

##### DOVECOT_USER_FILTER

  - e.g. `"(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"`

##### DOVECOT_PASS_FILTER

  - e.g. `"(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))"`

## Postgrey

##### ENABLE_POSTGREY

  - **0** => `postgrey` is disabled
  - 1 => `postgrey` is enabled

##### POSTGREY_DELAY

  - **300** => greylist for N seconds

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

##### POSTGREY_MAX_AGE

  - **35** => delete entries older than N days since the last time that they have been seen

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

##### POSTGREY_TEXT

  - **Delayed by postgrey** => response when a mail is greylisted

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

## SASL Auth

##### ENABLE_SASLAUTHD

  - **0** => `saslauthd` is disabled
  - 1 => `saslauthd` is enabled

##### SASLAUTHD_MECHANISMS

  - empty => pam
  - `ldap` => authenticate against ldap server
  - `shadow` => authenticate against local user db
  - `mysql` => authenticate against mysql db
  - `rimap` => authenticate against imap server
  - NOTE: can be a list of mechanisms like pam ldap shadow

##### SASLAUTHD_MECH_OPTIONS

  - empty => None
  - e.g. with SASLAUTHD_MECHANISMS rimap you need to specify the ip-address/servername of the imap server  ==> xxx.xxx.xxx.xxx

##### SASLAUTHD_LDAP_SERVER

  - empty => localhost

##### SASLAUTHD_LDAP_SSL

  - empty or 0 => `ldap://` will be used
  - 1 => `ldaps://` will be used

##### SASLAUTHD_LDAP_BIND_DN

  - empty => anonymous bind
  - specify an object with priviliges to search the directory tree
  - e.g. active directory: SASLAUTHD_LDAP_BIND_DN=cn=Administrator,cn=Users,dc=mydomain,dc=net
  - e.g. openldap: SASLAUTHD_LDAP_BIND_DN=cn=admin,dc=mydomain,dc=net

##### SASLAUTHD_LDAP_PASSWORD

  - empty => anonymous bind

##### SASLAUTHD_LDAP_SEARCH_BASE

  - empty => Reverting to SASLAUTHD_MECHANISMS pam
  - specify the search base

##### SASLAUTHD_LDAP_FILTER

  - empty => default filter `(&(uniqueIdentifier=%u)(mailEnabled=TRUE))`
  - e.g. for active directory: `(&(sAMAccountName=%U)(objectClass=person))`
  - e.g. for openldap: `(&(uid=%U)(objectClass=person))`

##### SASL_PASSWD

  - **empty** => No sasl_passwd will be created
  - string => `/etc/postfix/sasl_passwd` will be created with the string as password

