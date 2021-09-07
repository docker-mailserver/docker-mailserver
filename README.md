# Docker Mailserver

[![ci::status]][ci::github] [![docker::pulls]][docker::hub] [![documentation::badge]][documentation::web]

[ci::status]: https://img.shields.io/github/workflow/status/docker-mailserver/docker-mailserver/Build%2C%20Test%20%26%20Deploy?color=blue&label=CI&logo=github&logoColor=white&style=for-the-badge
[ci::github]: https://github.com/docker-mailserver/docker-mailserver/actions
[docker::pulls]: https://img.shields.io/docker/pulls/mailserver/docker-mailserver.svg?style=for-the-badge&logo=docker&logoColor=white
[docker::hub]: https://hub.docker.com/r/mailserver/docker-mailserver/
[documentation::badge]: https://img.shields.io/badge/DOCUMENTATION-GH%20PAGES-0078D4?style=for-the-badge&logo=git&logoColor=white
[documentation::web]: https://docker-mailserver.github.io/docker-mailserver/edge/

A fullstack but simple mail server (SMTP, IMAP, LDAP, Antispam, Antivirus, etc.). Only configuration files, no SQL database. Keep it simple and versioned. Easy to deploy and upgrade. [Documentation][documentation::web] via MkDocs. [Why this image was created](https://tvi.al/simple-mail-server-with-docker/).

If you have issues, read the full `README` **and** the [documentation][documentation::web] **for your version** (default is `edge`) first **before opening an issue**. The issue tracker is for issues, not for personal support.

1. [Included Services](#included-services)
2. [Issues and Contributing](https://docker-mailserver.github.io/docker-mailserver/edge/contributing/issues-and-pull-requests/)
3. [Requirements](#requirements)
4. [Usage](#usage)
5. [Examples](#examples)
6. [Environment Variables](https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/)
7. [Documentation][documentation::web]
8. [Release Notes](./CHANGELOG.md)

## Included Services

- [Postfix](http://www.postfix.org) with SMTP or LDAP auth
- [Dovecot](https://www.dovecot.org) for SASL, IMAP (or POP3), with LDAP Auth, Sieve and [quotas](https://docker-mailserver.github.io/docker-mailserver/edge/config/user-management/accounts#notes)
- [Amavis](https://www.amavis.org/)
- [SpamAssassin](http://spamassassin.apache.org/) supporting custom rules
- [ClamAV](https://www.clamav.net/) with automatic updates
- [OpenDKIM](http://www.opendkim.org)
- [OpenDMARC](https://github.com/trusteddomainproject/OpenDMARC)
- [Fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [Fetchmail](http://www.fetchmail.info/fetchmail-man.html)
- [Postscreen](http://www.postfix.org/POSTSCREEN_README.html)
- [Postgrey](https://postgrey.schweikert.ch/)
- [LetsEncrypt](https://letsencrypt.org/) and self-signed certificates
- [Setup script](https://docker-mailserver.github.io/docker-mailserver/edge/config/setup.sh) to easily configure and maintain your mailserver
- Basic [Sieve support](https://docker-mailserver.github.io/docker-mailserver/edge/config/advanced/mail-sieve) using dovecot
- SASLauthd with LDAP auth
- Persistent data and state
- [CI/CD](https://github.com/docker-mailserver/docker-mailserver/actions)
- [Extension Delimiters](http://www.postfix.org/postconf.5.html#recipient_delimiter) (`you+extension@example.com` go to `you@example.com`)

## Requirements

**Recommended**:

- 1 Core
- 2GB RAM
- Swap enabled for the container

**Minimum**:

- 1 vCore
- 512MB RAM

**Note:** You'll need to deactivate some services like ClamAV to be able to run on a host with 512MB of RAM. Even with 1G RAM you may run into problems without swap, see [FAQ](https://docker-mailserver.github.io/docker-mailserver/edge/faq/#what-system-requirements-are-required-to-run-docker-mailserver-effectively).

## Usage

### Available Images / Tags - Tagging Convention

[CI/CD](https://github.com/docker-mailserver/docker-mailserver/actions) will automatically build, test and push new images to container registries. Currently, the following registries are supported:

- [DockerHub](https://hub.docker.com/repository/docker/mailserver/docker-mailserver)
- [GitHub Container Registry](https://github.com/orgs/docker-mailserver/packages?repo_name=docker-mailserver)

All workflows are using the tagging convention listed below. It is subsequently applied to all images.

| Event        | Ref                   | Image Tags                    |
|--------------|-----------------------|-------------------------------|
| `push`       | `refs/heads/master`   | `edge`                        |
| `push tag`   | `refs/tags/[v]1.2.3`  | `1.2.3`, `1.2`, `1`, `latest` |

### Get the tools

Since Docker Mailserver `v10.2.0`, you can run the commands you previously executed with `./setup.sh ...` directly via `docker exec <CONTAINER> setup ...` if there already is a container running. The script `setup.sh` is here for convenience, and if you're using Docker or Docker Compose, it is recommended to use `setup.sh` if you're new to Docker Mailserver.

``` BASH
DMS_GITHUB_URL='https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master'
wget "${DMS_GITHUB_URL}/docker-compose.yml"
wget "${DMS_GITHUB_URL}/mailserver.env"
wget "${DMS_GITHUB_URL}/setup.sh"

chmod a+x ./setup.sh
./setup.sh help
```

Running `./setup.sh help` will also pull the `:latest` image (which is the latest stable release), if this has not been done beforehand.

**NOTE** _If you're using Docker Mailserver version `v10.1.x` or below_, you will need to get `setup.sh` with a specific version. Substitute `<VERSION>` with the mail server version you're using: `wget https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/<VERSION>/setup.sh`.

### Create a docker-compose environment

1. [Install the latest docker-compose](https://docs.docker.com/compose/install/)
2. Edit `docker-compose.yml` to your liking
   - substitute `<HOSTNAME>` and `<DOMAINNAME>` according to your domain
   - if you want to use SELinux for the `./config/:/tmp/docker-mailserver/` mount, append `-z` or `-Z`
3. Configure the mailserver container to your liking by editing `mailserver.env` ([**Documentation**](https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/))
   - this file supports [_only_ simple `VAR=VAL`](https://docs.docker.com/compose/env-file/) (**don't** quote your values)
   - variable substitution is **not** supported (e.g. :no_entry_sign: `OVERRIDE_HOSTNAME=$HOSTNAME.$DOMAINNAME` :no_entry_sign:)

### Get up and running

``` BASH
docker-compose up -d mailserver

# for SELinux, use -Z 
./setup.sh [-Z] email add <user@domain> [<password>]
./setup.sh [-Z] alias add postmaster@<domain> <user@domain>
./setup.sh [-Z] config dkim
```

If you're seeing error messages about unchecked errors, please **verify that you're using the right version of `setup.sh`**. Refer to the [Get the tools](#get-the-tools) section and / or execute `./setup.sh help` and read the `VERSION` section.

In case you're using LDAP, the setup looks a bit different as you do not add user accounts directly. Postfix doesn't know your domain(s) and you need to provide it when configuring DKIM:

``` BASH
./setup.sh config dkim domain '<domain.tld>[,<domain2.tld>]'
```

If you want to see detailed usage information, run `./setup.sh config dkim help`.

### Miscellaneous

#### DNS - DKIM

When keys are generated, you can configure your DNS server by just pasting the content of `config/opendkim/keys/domain.tld/mail.txt` to [set up DKIM](https://mxtoolbox.com/dmarc/dkim/setup/how-to-setup-dkim). See the [documentation](https://docker-mailserver.github.io/docker-mailserver/edge/config/best-practices/dkim/) for more details.

#### Custom User Changes & Patches

If you'd like to change, patch or alter files or behavior of `docker-mailserver`, you can use a script. See the [documentation](https://docker-mailserver.github.io/docker-mailserver/edge/config/advanced/override-defaults/user-patches/) for a detailed explanation.

#### Update `docker-mailserver`

Make sure to read the [CHANGELOG](https://github.com/docker-mailserver/docker-mailserver/blob/master/CHANGELOG.md) before, to be prepared for possible breaking changes.

``` BASH
docker-compose pull
docker-compose down
docker-compose up -d mailserver
```

You should see the new version number on startup, for example: `[ TASKLOG ]  Welcome to docker-mailserver 10.1.2`.

You're done! And don't forget to have a look at the remaining functions of the `setup.sh` script with `./setup.sh help`.

#### Supported Operating Systems

We are currently providing support for Linux. Windows is _not_ supported and is known to cause problems. Similarly, macOS is _not officially_ supported - but you may get it to work there. In the end, Linux should be your preferred operating system for this image, especially when using this mailserver in production.

#### Bare Domains

If you want to use a bare domain (`hostname` == `domainname`), see [FAQ](https://docker-mailserver.github.io/docker-mailserver/edge/faq#can-i-use-nakedbare-domains-no-host-name).

#### Support for Multiple Domains

`docker-mailserver` supports multiple domains out of the box, so you can do this:

``` BASH
./setup.sh email add user1@docker.example.com
./setup.sh email add user1@mail.example.de
./setup.sh email add user1@server.example.org
```

#### SPF/Forwarding Problems

If you got any problems with SPF and/or forwarding mails, give [SRS](https://github.com/roehling/postsrsd/blob/master/README.md) a try. You enable SRS by setting `ENABLE_SRS=1`. See the variable description for further information.

#### Ports

See the [documentation](https://docker-mailserver.github.io/docker-mailserver/edge/config/security/understanding-the-ports/) for further details and best practice advice, **especially regarding security concerns**.

#### Mailboxes (_aka IMAP Folders_)

`INBOX` is setup by default with the special IMAP folders `Drafts`, `Sent`, `Junk` and `Trash`. You can learn how to modify or add your own folders (_including additional special folders like `Archive`_) by visiting our docs page [_Customizing IMAP Folders_][docs-examples-imapfolders] for more information.

[docs-examples-imapfolders]: https://docker-mailserver.github.io/docker-mailserver/edge/examples/use-cases/imap-folders

## Examples

### With Relevant Environmental Variables

This example provides you only with a basic example of what a minimal setup could look like. We **strongly recommend** that you go through the configuration file yourself and adjust everything to your needs. The default [docker-compose.yml](./docker-compose.yml) can be used for the purpose out-of-the-box, see the [usage section](#usage).

``` YAML
version: '3.8'

services:
  mailserver:
    image: docker.io/mailserver/docker-mailserver:latest
    hostname: mail
    domainname: example.com
    container_name: mailserver
    ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
    volumes:
      - ./data/maildata:/var/mail
      - ./data/mailstate:/var/mail-state
      - ./data/maillogs:/var/log/mail
      - /etc/localtime:/etc/localtime:ro
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
```

#### LDAP setup

``` YAML
version: '3.8'

services:
  mailserver:
    image: docker.io/mailserver/docker-mailserver:latest
    hostname: mail
    domainname: example.com
    container_name: mailserver
    ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
    volumes:
      - ./data/maildata:/var/mail
      - ./data/mailstate:/var/mail-state
      - ./data/maillogs:/var/log/mail
      - /etc/localtime:/etc/localtime:ro
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
```
