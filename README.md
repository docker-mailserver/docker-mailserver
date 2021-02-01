# Docker Mailserver

[![ci::status]][ci::github] [![docker::pulls]][docker::hub]

[ci::status]: https://img.shields.io/github/workflow/status/docker-mailserver/docker-mailserver/Build%2C%20Test%20%26%20Deploy?color=blue&label=CI&logo=github&logoColor=white&style=for-the-badge
[ci::github]: https://github.com/docker-mailserver/docker-mailserver/actions
[docker::pulls]: https://img.shields.io/docker/pulls/mailserver/docker-mailserver.svg?style=for-the-badge&logo=docker&logoColor=white
[docker::hub]: https://hub.docker.com/r/mailserver/docker-mailserver/

A fullstack but simple mail server (SMTP, IMAP, LDAP, Antispam, Antivirus, etc.). Only configuration files, no SQL database. Keep it simple and versioned. Easy to deploy and upgrade.

[Why this image was created.](http://tvi.al/simple-mail-server-with-docker/)

1. [Included Services](#included-services)
2. [Opening Issues and Contributing](#opening-issues-and-contributing)
3. [Requirements](#requirements)
4. [Usage](#usage)
5. [Examples](#examples)
6. [Environment Variables](./ENVIRONMENT.md)
7. [Release Notes](./CHANGELOG.md)

## Included Services

- [Postfix](http://www.postfix.org) with SMTP or LDAP auth
- [Dovecot](https://www.dovecot.org) for SASL, IMAP (or POP3), with LDAP Auth, Sieve and [quotas](https://github.com/docker-mailserver/docker-mailserver/wiki/Configure-Accounts#mailbox-quota)
- [Amavis](https://www.amavis.org/)
- [Spamassasin](http://spamassassin.apache.org/) supporting custom rules
- [ClamAV](https://www.clamav.net/) with automatic updates
- [OpenDKIM](http://www.opendkim.org)
- [OpenDMARC](https://github.com/trusteddomainproject/OpenDMARC)
- [Fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [Fetchmail](http://www.fetchmail.info/fetchmail-man.html)
- [Postscreen](http://www.postfix.org/POSTSCREEN_README.html)
- [Postgrey](https://postgrey.schweikert.ch/)
- [LetsEncrypt](https://letsencrypt.org/) and self-signed certificates
- [Setup script](https://github.com/docker-mailserver/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh) to easily configure and maintain your mailserver
- Basic [Sieve support](https://github.com/docker-mailserver/docker-mailserver/wiki/Configure-Sieve-filters) using dovecot
- SASLauthd with LDAP auth
- Persistent data and state
- [CI/CD](https://github.com/docker-mailserver/docker-mailserver/actions)
- [Extension Delimiters](http://www.postfix.org/postconf.5.html#recipient_delimiter) (`you+extension@example.com` go to `you@example.com`)

## Opening Issues and Contributing

**Before opening an issue**, read this `README` carefully, use the [Wiki](https://github.com/docker-mailserver/docker-mailserver/wiki/), the Postfix/Dovecot documentation and your search engine you trust. The issue tracker is not meant to be used for unrelated questions! If you'd like to contribute, read [`CONTRIBUTING.md`](./CONTRIBUTING.md) thoroughly.

## Requirements

**Recommended**:

- 1 Core
- 1-2GB RAM
- Swap enabled for the container

**Minimum**:

- 1 vCore
- 512MB RAM

**Note:** You'll need to deactivate some services like ClamAV to be able to run on a host with 512MB of RAM. Even with 1G RAM you may run into problems without swap, see [FAQ](https://github.com/docker-mailserver/docker-mailserver/wiki/FAQ-and-Tips).

## Usage

### Available image sources / tags

The [CI/CD workflows](https://github.com/docker-mailserver/docker-mailserver/actions) automatically build, test and push new images to container registries. Currently, the following registries are supported:
- [DockerHub](https://hub.docker.com/repository/docker/mailserver/docker-mailserver)
- [GitHub Container Registry](https://github.com/orgs/docker-mailserver/packages?repo_name=docker-mailserver)

All workflows are using the **tagging convention** listed below. It is subsequently applied to all images pushed to supported container registries:

| Event        | Ref                   | Commit SHA | Image Tags                    |
|--------------|-----------------------|------------|-------------------------------|
| `push`       | `refs/heads/master`   | `cf20257`  | `edge`                        |
| `push`       | `refs/heads/stable`   | `cf20257`  | `stable`                      |
| `push tag`   | `refs/tags/1.2.3`     | `ad132f5`  | `1.2.3`, `1.2`, `1`, `latest` |
| `push tag`   | `refs/tags/v1.2.3`    | `ad132f5`  | `1.2.3`, `1.2`, `1`, `latest` |

### Get the tools

Download the `docker-compose.yml`, `compose.env`, `mailserver.env` and the `setup.sh` files:

``` BASH
wget https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/setup.sh
wget https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/docker-compose.yml
wget https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/mailserver.env
wget -O .env https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/compose.env

chmod a+x ./setup.sh
```

### Create a docker-compose environment

- [Install the latest docker-compose](https://docs.docker.com/compose/install/)
- Edit the files `.env` and `mailserver.env` to your liking:
  - `.env` contains the configuration for Docker Compose
  - `mailserver.env` contains the configuration for the mailserver container
  - these files supports [only simple `VAR=VAL`](https://docs.docker.com/compose/env-file/)
  - don't quote your values
  - variable substitution is *not* supported (e.g. `OVERRIDE_HOSTNAME=$HOSTNAME.$DOMAINNAME`).
- Variables in `.env` are expanded in the `docker-compose.yml` file **only** and **not** in the container. The file `mailserver.env` serves this case where environment variables are used in the container.
- If you want to use a bare domain (host name = domain name), see [FAQ](https://github.com/docker-mailserver/docker-mailserver/wiki/FAQ-and-Tips#can-i-use-nakedbare-domains-no-host-name)

### Get up and running

If you'd like to use SELinux, add `-Z` to the variable `SELINUX_LABEL` in `.env`. If you want the volume bind mount to be shared among other containers switch `-Z` to `-z`

``` BASH
docker-compose up -d mail

# without SELinux
./setup.sh email add <user@domain> [<password>]
./setup.sh alias add postmaster@<domain> <user@domain>
./setup.sh config dkim

# with SELinux
./setup.sh -Z email add <user@domain> [<password>]
./setup.sh -Z alias add postmaster@<domain> <user@domain>
./setup.sh -Z config dkim
```

If you are using a LDAP setup the setup looks a bit different as you do not add user accounts directly. Therefore `postfix` doesn't know your domain(s) and you need to provide it when configuring `dkim`:

``` BASH
docker-compose up -d mail

./setup.sh config dkim <key-size> <domain.tld>[,<domain2.tld>]
```

### Miscellaneous

#### DNS - DKIM

When keys are generated, you can configure your DNS server by just pasting the content of `config/opendkim/keys/domain.tld/mail.txt` to [set up DKIM](https://mxtoolbox.com/dmarc/dkim/setup/how-to-setup-dkim).

#### Custom user changes & patches

If you'd like to change, patch or alter files or behavior of `docker-mailserver`, you can use a script. Just place it the `config/` folder that is created on startup and call it `user-patches.sh`. The setup is done like this:

``` BASH
# 1. Either create the config/ directory yourself
#    or let docker-mailserver create it on initial
#    startup
/where/docker-mailserver/resides/ $ mkdir config && cd config

# 2. Create the user-patches.sh script and make it
#    executable
/where/docker-mailserver/resides/config/ $ touch user-patches.sh
/where/docker-mailserver/resides/config/ $ chmod +x user-patches.sh

# 3. Edit it
/where/docker-mailserver/resides/config/ $ vi user-patches.sh
/where/docker-mailserver/resides/config/ $ cat user-patches.sh
#! /bin/bash

# ! THIS IS AN EXAMPLE !

# If you modify any supervisord configuration, make sure
# to run `supervisorctl update` and/or `supervisorctl reload` afterwards.

# shellcheck source=/dev/null
. /usr/local/bin/helper-functions.sh

_notify 'Applying user-patches'

if ! grep '192.168.0.1' /etc/hosts
then
  echo -e '192.168.0.1 some.domain.com' >> /etc/hosts
fi
```

And you're done. The user patches script runs right before starting daemons. That means, all the other configuration is in place, so the script can make final adjustments.

#### Supported Operating Systems

We are currently providing support for Linux. Windows is _not_ supported and is known to cause problems. Similarly, macOS is _not officially_ supported - but you may get it to work there. In the end, Linux should be your preferred operating system for this image, especially when using this mailserver in production.

#### Support for Multiple Domains

`docker-mailserver` supports multiple domains out of the box, so you can do this:

``` BASH
./setup.sh email add user1@docker.example.com
./setup.sh email add user1@mail.example.de
./setup.sh email add user1@server.example.org
```

#### Updating `docker-mailserver`

``` BASH
docker-compose down
docker pull docker.io/mailserver/docker-mailserver:<VERSION TAG>
docker-compose up -d mailserver
```

You're done! And don't forget to have a look at the remaining functions of the `setup.sh` script with `./setup.sh -h`.

#### SPF/Forwarding Problems

If you got any problems with SPF and/or forwarding mails, give [SRS](https://github.com/roehling/postsrsd/blob/master/README.md) a try. You enable SRS by setting `ENABLE_SRS=1`. See the variable description for further information.

#### Exposed ports

| Protocol | Opt-in Encryption &#185; | Enforced Encryption | Purpose        |
| :------: | :----------------------: | :-----------------: | :------------: |
| SMTP     | 25                       | N/A                 | Transfer&#178; |
| ESMTP    | 587                      | 465&#179;           | Submission     |
| POP3     | 110                      | 995                 | Retrieval      |
| IMAP4    | 143                      | 993                 | Retrieval      |

1. A connection *may* be secured over TLS when both ends support `STARTTLS`. On ports 110, 143 and 587, `docker-mailserver` will reject a connection that cannot be secured. Port 25 is [required](https://serverfault.com/questions/623692/is-it-still-wrong-to-require-starttls-on-incoming-smtp-messages) to support insecure connections.
2. Receives email and filters for spam and viruses. For submitting outgoing mail you should prefer the submission ports(465, 587), which require authentication. Unless a relay host is configured, outgoing email will leave the server via port 25(thus outbound traffic must not be blocked by your provider or firewall).
3. A submission port since 2018, [RFC 8314](https://tools.ietf.org/html/rfc8314). Originally a secure variant of port 25.

See the [wiki](https://github.com/docker-mailserver/docker-mailserver/wiki) for further details and best practice advice, especially regarding security concerns.

## Examples

### With Relevant Environmental Variables

This example provides you only with a basic example of what a minimal setup could look like. We **strongly recommend** that you go through the configuration file yourself and adjust everything to your needs. The default [docker-compose.yml](./docker-compose.yml) can be used for the purpose out-of-the-box, see the [usage section](#usage).

``` YAML
version: '3.8'

services:
  mailserver:
    image: docker.io/mailserver/docker-mailserver:latest
    hostname: mail          # ${HOSTNAME}
    domainname: domain.com  # ${DOMAINNAME}
    container_name: mail    # ${CONTAINER_NAME}
    ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
    volumes:
      - maildata:/var/mail
      - mailstate:/var/mail-state
      - maillogs:/var/log/mail
      - ./config/:/tmp/docker-mailserver/
    environment:
      - ENABLE_SPAMASSASSIN=1
      - SPAMASSASSIN_SPAM_TO_INBOX=1
      - ENABLE_CLAMAV=1
      - ENABLE_FAIL2BAN=1
      - ENABLE_POSTGREY=1
      - ENABLE_SASLAUTHD=0
      - ONE_DIR=1
      - DMS_DEBUG=0
    cap_add:
      - NET_ADMIN
      - SYS_PTRACE
    restart: always

volumes:
  maildata:
  mailstate:
  maillogs:
```

#### LDAP setup

``` YAML
version: '3.8'

services:
  mailserver:
    image: docker.io/mailserver/docker-mailserver:latest
    hostname: mail          # ${HOSTNAME}
    domainname: domain.com  # ${DOMAINNAME}
    container_name: mail    # ${CONTAINER_NAME}
    ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
    volumes:
      - maildata:/var/mail
      - mailstate:/var/mail-state
      - maillogs:/var/log/mail
      - ./config/:/tmp/docker-mailserver/
    environment:
      - ENABLE_SPAMASSASSIN=1
      - SPAMASSASSIN_SPAM_TO_INBOX=1
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
      - LDAP_QUERY_FILTER_USER=(&(mail=%s)(mailEnabled=TRUE))
      - LDAP_QUERY_FILTER_GROUP=(&(mailGroupMember=%s)(mailEnabled=TRUE))
      - LDAP_QUERY_FILTER_ALIAS=(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))
      - LDAP_QUERY_FILTER_DOMAIN=(|(&(mail=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailGroupMember=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailalias=*@%s)(objectClass=PostfixBookMailForward)))
      - DOVECOT_PASS_FILTER=(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))
      - DOVECOT_USER_FILTER=(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))
      - ENABLE_SASLAUTHD=1
      - SASLAUTHD_MECHANISMS=ldap
      - SASLAUTHD_LDAP_SERVER=ldap
      - SASLAUTHD_LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain
      - SASLAUTHD_LDAP_PASSWORD=admin
      - SASLAUTHD_LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain
      - SASLAUTHD_LDAP_FILTER=(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%U))
      - POSTMASTER_ADDRESS=postmaster@localhost.localdomain
      - POSTFIX_MESSAGE_SIZE_LIMIT=100000000
    cap_add:
      - NET_ADMIN
      - SYS_PTRACE
    restart: always

volumes:
  maildata:
  mailstate:
  maillogs:
```
