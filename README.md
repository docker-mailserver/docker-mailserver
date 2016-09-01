# docker-mailserver

[![Build Status](https://travis-ci.org/tomav/docker-mailserver.svg?branch=master)](https://travis-ci.org/tomav/docker-mailserver) [![Docker Pulls](https://img.shields.io/docker/pulls/tvial/docker-mailserver.svg)](https://hub.docker.com/r/tvial/docker-mailserver/) [![Github Stars](https://img.shields.io/github/stars/tomav/docker-mailserver.svg?label=github%20%E2%98%85)](https://github.com/tomav/docker-mailserver/) [![Github Stars](https://img.shields.io/github/contributors/tomav/docker-mailserver.svg)](https://github.com/tomav/docker-mailserver/) [![Github Forks](https://img.shields.io/github/forks/tomav/docker-mailserver.svg?label=github%20forks)](https://github.com/tomav/docker-mailserver/)

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
- fetchmail
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

Adapt this file with your FQDN. Install [docker-compose](https://docs.docker.com/compose/) in the version `1.6` or higher.

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
    touch config/postfix-accounts.cf
    docker run --rm \
      -e MAIL_USER=user1@domain.tld \
      -e MAIL_PASS=mypassword \
      -ti tvial/docker-mailserver:latest \
      /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf

#### Generate DKIM keys

    docker run --rm \
      -v "$(pwd)/config":/tmp/docker-mailserver \
      -ti tvial/docker-mailserver:latest generate-dkim-config

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opendkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone.

Note: if you are using ldap, you will have to generate the key firsts with the non ldap mode then move the generated `opendkim` folders in `config`

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

##### ENABLE_LDAP

  - **empty** => LDAP disabled
  - "true" => Enables LDAP

If you enable LDAP, don't forget to add the following lines to your `docker-compose.yml`:

  volumes:
    - ./config/conf.d/auth-ldap.conf.ext:/tmp/docker-mailserver/conf.d/auth-ldap.conf.ext
    - ./config/ldap-accounts.cf:/tmp/docker-mailserver/ldap-accounts.cf
    - ./config/ldap-aliases.cf:/tmp/docker-mailserver/ldap-aliases.cf
    - ./config/ldap-domains.cf:/tmp/docker-mailserver/ldap-domains.cf

Read this [article](https://wiki.gandi.net/en/hosting/using-linux/tutorials/debian/mail-server-ldap) more details on how to configure OpenLDAP with postfix

__Example of configuration :__

If you need a OpenLDAP Docker image, this configuration was test with this [image](https://github.com/osixia/docker-openldap)

06-authldap.ldif is the user schema use for creating the account below

  dn: cn=authldap,cn=schema,cn=config
  changetype: add
  objectClass: olcSchemaConfig
  cn: authldap
  olcAttributeTypes: {0}( 1.3.6.1.4.1.10018.1.1.1 NAME 'mailbox' DESC 'The abs
   olute path to the mailbox for a mail account in a non-default location' EQU
   ALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 SINGLE-VALUE )
  olcAttributeTypes: {1}( 1.3.6.1.4.1.10018.1.1.2 NAME 'quota' DESC 'A string 
   that represents the quota on a mailbox' EQUALITY caseExactIA5Match SYNTAX 1
   .3.6.1.4.1.1466.115.121.1.26 SINGLE-VALUE )
  olcAttributeTypes: {2}( 1.3.6.1.4.1.10018.1.1.3 NAME 'clearPassword' DESC 'A
    separate text that stores the mail account password in clear text' EQUALIT
   Y octetStringMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.40{128} )
  olcAttributeTypes: {3}( 1.3.6.1.4.1.10018.1.1.4 NAME 'maildrop' DESC 'RFC822
    Mailbox - mail alias' EQUALITY caseIgnoreIA5Match SUBSTR caseIgnoreIA5Subs
   tringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.26{256} )
  olcAttributeTypes: {4}( 1.3.6.1.4.1.10018.1.1.5 NAME 'mailsource' DESC 'Mess
   age source' EQUALITY caseIgnoreIA5Match SUBSTR caseIgnoreIA5SubstringsMatch
    SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
  olcAttributeTypes: {5}( 1.3.6.1.4.1.10018.1.1.6 NAME 'virtualdomain' DESC 'A
    mail domain that is mapped to a single mail account' EQUALITY caseIgnoreIA
   5Match SUBSTR caseIgnoreIA5SubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.
   1.26 )
  olcAttributeTypes: {6}( 1.3.6.1.4.1.10018.1.1.7 NAME 'virtualdomainuser' DES
   C 'Mailbox that receives mail for a mail domain' EQUALITY caseIgnoreIA5Matc
   h SUBSTR caseIgnoreIA5SubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 
   )
  olcAttributeTypes: {7}( 1.3.6.1.4.1.10018.1.1.8 NAME 'defaultdelivery' DESC 
   'Default mail delivery instructions' EQUALITY caseExactIA5Match SYNTAX 1.3.
   6.1.4.1.1466.115.121.1.26 )
  olcAttributeTypes: {8}( 1.3.6.1.4.1.10018.1.1.9 NAME 'disableimap' DESC 'Set
    this attribute to 1 to disable IMAP access' EQUALITY caseExactIA5Match SYN
   TAX 1.3.6.1.4.1.1466.115.121.1.26 )
  olcAttributeTypes: {9}( 1.3.6.1.4.1.10018.1.1.10 NAME 'disablepop3' DESC 'Se
   t this attribute to 1 to disable POP3 access' EQUALITY caseExactIA5Match SY
   NTAX 1.3.6.1.4.1.1466.115.121.1.26 )
  olcAttributeTypes: {10}( 1.3.6.1.4.1.10018.1.1.11 NAME 'disablewebmail' DESC
    'Set this attribute to 1 to disable IMAP access' EQUALITY caseExactIA5Matc
   h SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
  olcAttributeTypes: {11}( 1.3.6.1.4.1.10018.1.1.12 NAME 'sharedgroup' DESC 'V
   irtual shared group' EQUALITY caseExactIA5Match SYNTAX 1.3.6.1.4.1.1466.115
   .121.1.26 )
  olcAttributeTypes: {12}( 1.3.6.1.4.1.10018.1.1.13 NAME 'disableshared' DESC 
   'Set this attribute to 1 to disable shared mailbox usage' EQUALITY caseExac
   tIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
  olcAttributeTypes: {13}( 1.3.6.1.4.1.10018.1.1.14 NAME 'mailhost' DESC 'Host
    to which incoming POP/IMAP connections should be proxied' EQUALITY caseIgn
   oreIA5Match SYNTAX 1.3.6.1.4.1.1466.115.121.1.26{256} )
  olcObjectClasses: {0}( 1.3.6.1.4.1.10018.1.2.1 NAME 'CourierMailAccount' DES
   C 'Mail account object as used by the Courier mail server' SUP top AUXILIAR
   Y MUST ( mail $ homeDirectory ) MAY ( uidNumber $ gidNumber $ mailbox $ uid
    $ cn $ gecos $ description $ loginShell $ quota $ userPassword $ clearPass
   word $ defaultdelivery $ disableimap $ disablepop3 $ disablewebmail $ share
   dgroup $ disableshared $ mailhost ) )
  olcObjectClasses: {1}( 1.3.6.1.4.1.10018.1.2.2 NAME 'CourierMailAlias' DESC 
   'Mail aliasing/forwarding entry' SUP top AUXILIARY MUST ( mail $ maildrop )
    MAY ( mailsource $ description ) )
  olcObjectClasses: {2}( 1.3.6.1.4.1.10018.1.2.3 NAME 'CourierDomainAlias' DES
   C 'Domain mail aliasing/forwarding entry' SUP top AUXILIARY MUST ( virtuald
   omain $ virtualdomainuser ) MAY ( mailsource $ description ) )

10-mail-tree.ldif

    # -------------------------------------------------------------------- 
    # Create the dc=mail under dc=domain,dc=com
    # -------------------------------------------------------------------- 
    dn: dc=mail,dc=domain,dc=com
    changetype: add
    dc: mail
    o: mail
    objectClass: top
    objectClass: dcObject
    objectClass: organization

    dn: dc=domain.com,dc=mail,dc=domain,dc=com
    changetype: add
    o: domain.com
    dc: domain.com
    description: virtualDomain
    objectClass: top
    objectClass: dcObject
    objectClass: organization

    dn: dc=mailAccount,dc=domain.com,dc=mail,dc=domain,dc=com
    changetype: add
    dc: mailAccount
    o: mailAccount
    objectClass: top
    objectClass: dcObject
    objectClass: organization

    dn: dc=mailAlias,dc=domain.com,dc=mail,dc=domain,dc=com
    changetype: add
    dc: mailAlias
    o: mailAlias
    objectClass: top
    objectClass: dcObject
    objectClass: organization

50-user-email.ldif entry used on my OpenLDAP server

_Note : The `userPassword` present here is the SSHA representation of "enter"_

    # -------------------------------------------------------------------- 
    # Create mail accounts
    # -------------------------------------------------------------------- 
    dn: mail=somebody@domain.com,dc=mailAccount,dc=domain.com,dc=mail,dc=domain,dc=com
    changetype: add
    sn: Wayne
    givenName: Bruce
    displayName: Bruce Wayne
    cn: somebody@domain.com
    mail: somebody@domain.com
    mailbox: domaine.com/bruce.wayne/
    homeDirectory: /var/mail
    objectClass: top
    objectClass: inetOrgPerson
    objectClass: CourierMailAccount
    userPassword: {SSHA}Ys9NZMHhZ7woTrgK7GUXXQ3NkMEH2gom

    # -------------------------------------------------------------------- 
    # Create alias accounts
    # -------------------------------------------------------------------- 
    dn: mail=batman@domain.com,dc=mailAlias,dc=domain.com,dc=mail,dc=domain,dc=com
    changetype: add
    cn: batman@domain.com
    mail: batman@domain.com
    maildrop: bruce.wayne@domain.com
    sn: Wayne
    givenName: Bruce
    displayName: Bruce Wayne
    objectClass: top
    objectClass: inetOrgPerson
    objectClass: CourierMailAlias

Create a file `conf.d/auth-ldap.conf.ext`, this will override the current authentication mechanism

    hosts           = ldap.domain.com
    ldap_version    = 3
    auth_bind       = yes
    dn              = cn=admin,dc=domain,dc=com
    dnpass          = <Password>
    base            = dc=mail,dc=domain,dc=com
    user_filter     = (&(objectClass=CourierMailAccount)(mail=%u))
    pass_filter     = (&(objectClass=CourierMailAccount)(mail=%u))
    user_attrs      = uidNumber=5000,gidNumber=5000,homeDirectory=home,mailbox=mail
    default_pass_scheme = SSHA

Create a file `config/conf.d/ldap-accounts.cf`

    server_host = ldap.domain.com # Host of your ldap server
    server_port = 389 
    search_base = dc=mail,dc=domain,dc=com # Where to search mail account from
    query_filter = (&(objectClass=CourierMailAccount)(mail=%s)) # This require to have the CourierMailAccount class (see below)
    result_attribute = mailbox
    bind = yes
    bind_dn = cn=readonly,dc=domain,dc=com
    bind_pw = readonlypw
    version = 3

##### ENABLE_MANAGESIEVE

  - **empty** => Managesieve service disabled
  - 1 => Enables Managesieve on port 4190

##### ENABLE_FETCHMAIL
  - **empty** => `fetchmail` disabled
  - 1 => `fetchmail` enabled

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
  - manual => Let's you manually specify locations of your SSL certificates for non-standard cases
  - self-signed => Enables self-signed certificates

Please read [the SSL page in the wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-SSL) for more information.

##### PERMIT_DOCKER

Set different options for mynetworks option (can be overwrite in postfix-main.cf)
  - **empty** => localhost only
  - host => Add docker host (ipv4 only)
  - network => Add all docker containers (ipv4 only)
