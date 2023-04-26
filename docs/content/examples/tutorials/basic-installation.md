---
title: 'Tutorials | Basic Installation'
---

## A Basic Example With Relevant Environmental Variables

This example provides you only with a basic example of what a minimal setup could look like. We **strongly recommend** that you go through the configuration file yourself and adjust everything to your needs. The default [compose.yaml](https://github.com/docker-mailserver/docker-mailserver/blob/master/compose.yaml) can be used for the purpose out-of-the-box, see the [_Usage_ chapter](../../usage.md).

``` YAML
services:
  mailserver:
    image: ghcr.io/docker-mailserver/docker-mailserver:latest
    container_name: mailserver
    # Provide the FQDN of your mail server here (Your DNS MX record should point to this value)
    hostname: mail.example.com
    ports:
      - "25:25"
      - "465:465"
      - "587:587"
      - "993:993"
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/mail-state/:/var/mail-state/
      - ./docker-data/dms/mail-logs/:/var/log/mail/
      - ./docker-data/dms/config/:/tmp/docker-mailserver/
      - /etc/localtime:/etc/localtime:ro
    environment:
      - ENABLE_RSPAMD=1
      - ENABLE_CLAMAV=1
      - ENABLE_FAIL2BAN=1
    cap_add:
      - NET_ADMIN # For Fail2Ban to work
    restart: always
```

## A Basic LDAP Setup

**Note** There are currently no LDAP maintainers. If you encounter issues, please raise them in the issue tracker, but be aware that the core maintainers team will most likely not be able to help you. **We would appreciate and we encourage everyone to actively participate in maintaining LDAP-related code by becoming a maintainer!**

``` YAML
services:
  mailserver:
    image: ghcr.io/docker-mailserver/docker-mailserver:latest
    container_name: mailserver
    # Provide the FQDN of your mail server here (Your DNS MX record should point to this value)
    hostname: mail.example.com
    ports:
      - "25:25"
      - "465:465"
      - "587:587"
      - "993:993"
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/mail-state/:/var/mail-state/
      - ./docker-data/dms/mail-logs/:/var/log/mail/
      - ./docker-data/dms/config/:/tmp/docker-mailserver/
      - /etc/localtime:/etc/localtime:ro
    environment:
      - ACCOUNT_PROVISIONER=LDAP
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
    restart: always
```

## Using DMS as a local mail relay for containers

!!! info

    This was originally a community contributed guide. Please let us know via a Github Issue if you're having any difficulty following the guide so that we can update it.

This guide is focused on only using [SMTP ports (not POP3 and IMAP)][docs-ports] with the intent to relay mail received from another service to an external email address (eg: `user@gmail.com`). It is not intended for mailbox storage of real users.

In this setup DMS is not intended to receive email from the outside world, so no anti-spam or anti-virus software is needed, making the service lighter to run.

!!! tip "`setup`"

    The `setup` command used below is to be [run inside the container][docs-usage].

!!! warning "Open Relays"

    Adding the docker network's gateway to the list of trusted hosts (_eg: using the `network` or `connected-networks` option_), can create an [**open relay**](https://en.wikipedia.org/wiki/Open_mail_relay). For instance [if IPv6 is enabled on the host machine, but not in Docker][github-issue-1405-comment].

1. Create the file `compose.yaml` with a content like this:

    !!! example

        ```yaml
        services:
          mailserver:
            image: ghcr.io/docker-mailserver/docker-mailserver:latest
            container_name: mailserver
            # Provide the FQDN of your mail server here (Your DNS MX record should point to this value)
            hostname: mail.example.com
            ports:
              - "25:25"
              - "587:587"
              - "465:465"
            volumes:
              - ./docker-data/dms/mail-data/:/var/mail/
              - ./docker-data/dms/mail-state/:/var/mail-state/
              - ./docker-data/dms/mail-logs/:/var/log/mail/
              - ./docker-data/dms/config/:/tmp/docker-mailserver/
              - /etc/localtime:/etc/localtime:ro
            environment:
              - ENABLE_FAIL2BAN=1
              # Using letsencrypt for SSL/TLS certificates:
              - SSL_TYPE=letsencrypt
              # Allow sending emails from other docker containers:
              # Beware creating an Open Relay: https://docker-mailserver.github.io/docker-mailserver/latest/config/environment/#permit_docker
              - PERMIT_DOCKER=network
              # You may want to enable this: https://docker-mailserver.github.io/docker-mailserver/latest/config/environment/#spoof_protection
              # See step 6 below, which demonstrates setup with enabled/disabled SPOOF_PROTECTION:
              - SPOOF_PROTECTION=0
            cap_add:
              - NET_ADMIN # For Fail2Ban to work
            restart: always
        ```

    The docs have a detailed page on [Environment Variables][docs-environment] for reference.

    ??? tip "Firewalled ports"

        If you have a firewall running, you may need to open ports `25`, `587` and `465`.

        For example, with the firewall `ufw`, run:

        ```sh
        ufw allow 25
        ufw allow 587
        ufw allow 465
        ```

        **Caution:** This may [not be sound advice][github-issue-ufw].

2. Configure your DNS service to use an MX record for the _hostname_ (eg: `mail`) you configured in the previous step and add the [SPF][docs-spf] TXT record.

    !!! tip "If you manually manage the DNS zone file for the domain"

        It would look something like this:

        ```txt
        $ORIGIN example.com
        @     IN  A      10.11.12.13
        mail  IN  A      10.11.12.13

        ; mail server for example.com
        @     IN  MX  10 mail.example.com.

        ; Add SPF record
        @     IN  TXT    "v=spf1 mx -all"
        ```

        Then don't forget to change the `SOA` serial number, and to restart the service.

3. [Generate DKIM keys][docs-dkim] for your domain via `setup config dkim`.

    Copy the content of the file `docker-data/dms/config/opendkim/keys/example.com/mail.txt` and add it to your DNS records as a TXT like SPF was handled above.

    I use [bind9](https://github.com/docker-scripts/bind9) for managing my domains, so I just paste it on `example.com.db`:

    ```txt
    mail._domainkey IN      TXT     ( "v=DKIM1; h=sha256; k=rsa; "
            "p=MIIBIjANBgkqhkiG9w0BAQEFACAQ8AMIIBCgKCAQEAaH5KuPYPSF3Ppkt466BDMAFGOA4mgqn4oPjZ5BbFlYA9l5jU3bgzRj3l6/Q1n5a9lQs5fNZ7A/HtY0aMvs3nGE4oi+LTejt1jblMhV/OfJyRCunQBIGp0s8G9kIUBzyKJpDayk2+KJSJt/lxL9Iiy0DE5hIv62ZPP6AaTdHBAsJosLFeAzuLFHQ6USyQRojefqFQtgYqWQ2JiZQ3"
            "iqq3bD/BVlwKRp5gH6TEYEmx8EBJUuDxrJhkWRUk2VDl1fqhVBy8A9O7Ah+85nMrlOHIFsTaYo9o6+cDJ6t1i6G1gu+bZD0d3/3bqGLPBQV9LyEL1Rona5V7TJBGg099NQkTz1IwIDAQAB" )  ; ----- DKIM key mail for example.com
    ```

4. Get an SSL certificate, [we have a guide for you here][docs-ssl] (_Let's Encrypt_ is a popular service to get free SSL certificates).

5. Start DMS and check the terminal output for any errors: `docker compose up`.

6. Create email accounts and aliases:

    !!! example "With `SPOOF_PROTECTION=0`"

        ```sh
        setup email add admin@example.com passwd123
        setup email add info@example.com passwd123
        setup alias add admin@example.com external-account@gmail.com
        setup alias add info@example.com external-account@gmail.com
        setup email list
        setup alias list
        ```

        Aliases make sure that any email that comes to these accounts is forwarded to your third-party email address (`external-account@gmail.com`), where they are retrieved (_eg: via third-party web or mobile app_), instead of connecting directly to `docker-mailserer` with POP3 / IMAP.

    !!! example "With `SPOOF_PROTECTION=1`"

        ```sh
        setup email add admin.gmail@example.com passwd123
        setup email add info.gmail@example.com passwd123
        setup alias add admin@example.com admin.gmail@example.com
        setup alias add info@example.com info.gmail@example.com
        setup alias add admin.gmail@example.com external-account@gmail.com
        setup alias add info.gmail@example.com external-account@gmail.com
        setup email list
        setup alias list
        ```

        This extra step is required to avoid the `553 5.7.1 Sender address rejected: not owned by user` error (_the accounts used for submitting mail to Gmail are `admin.gmail@example.com` and `info.gmail@example.com`_)

7. Send some test emails to these addresses and make other tests. Once everything is working well, stop the container with `ctrl+c` and start it again as a daemon: `docker compose up -d`.

[docs-ports]: ../../config/security/understanding-the-ports.md
[docs-environment]: ../../config/environment.md
[docs-spf]: ../../config/best-practices/dkim_dmarc_spf.md#spf
[docs-dkim]: ../../config/best-practices/dkim_dmarc_spf.md#dkim
[docs-ssl]: ../../config/security/ssl.md#lets-encrypt-recommended
[docs-usage]: ../../usage.md#get-up-and-running
[github-issue-ufw]: https://github.com/docker-mailserver/docker-mailserver/issues/3151
[github-issue-1405-comment]: https://github.com/docker-mailserver/docker-mailserver/issues/1405#issuecomment-590106498
