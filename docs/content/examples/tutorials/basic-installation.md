---
title: 'Tutorials | Basic Installation'
---

## Setting up a Simple Mail-Server

This is a community contributed guide. Please let us know via a Github Issue if you're having any difficulty following the guide so that we can update it.

This guide is focused on only using [SMTP ports (not POP3 and IMAP)][docs-ports] with the intent to send received mail to another MTA service such as _Gmail_. It is not intended to have a MUA client (_eg: Thunderbird_) to retrieve mail directly from `docker-mailserver` via POP3/IMAP.

In this setup `docker-mailserver` is not intended to receive email externally, so no anti-spam or anti-virus software is needed, making the service lighter to run.

!!! warning "Open Relays"

    Adding the docker network's gateway to the list of trusted hosts (_eg: using the `network` or `connected-networks` option_), can create an [**open relay**](https://en.wikipedia.org/wiki/Open_mail_relay). For instance [if IPv6 is enabled on the host machine, but not in Docker][github-issue-1405-comment].

1. If you're running a version of `docker-mailserver` earlier than v10.2, [you'll need to get `setup.sh`][docs-setup-script]. Otherwise you can substitute `./setup.sh <command>` with `docker exec mailserver setup <command>`.

2. Pull the docker image: `docker pull docker.io/mailserver/docker-mailserver:latest`.

3. Create the file `docker-compose.yml` with a content like this:

    !!! example

        ```yaml
        version: '3.8'

        services:
          mailserver:
            image: docker.io/mailserver/docker-mailserver:latest
            container_name: mailserver
            hostname: mail
            # Change this to your domain, it is used for your email accounts (eg: user@example.com):
            domainname: example.com
            ports:
              - "25:25"
              - "587:587"
              - "465:465"
            volumes:
              - ./docker-data/dms/mail-data/:/var/mail/
              - ./docker-data/dms/mail-state/:/var/mail-state/
              - ./docker-data/dms/mail-logs/:/var/log/mail/
              - ./docker-data/dms/config/:/tmp/docker-mailserver/
              # The "from" path will vary based on where your certs are locally:
              - ./docker-data/nginx-proxy/certs/:/etc/letsencrypt/
              - /etc/localtime:/etc/localtime:ro
            environment:
              - ENABLE_FAIL2BAN=1
              # Using letsencrypt for SSL/TLS certificates
              - SSL_TYPE=letsencrypt
              # Allow sending emails from other docker containers
              # Beware creating an Open Relay: https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/#permit_docker
              - PERMIT_DOCKER=network
              # All env below are default settings:
              - ONE_DIR=1
              - ENABLE_POSTGREY=0
              - ENABLE_CLAMAV=0
              - ENABLE_SPAMASSASSIN=0
              # You may want to enable this: https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/#spoof_protection
              # See step 8 below, which demonstrates setup with enabled/disabled SPOOF_PROTECTION:
              - SPOOF_PROTECTION=0
            cap_add:
              - NET_ADMIN # For Fail2Ban to work
        ```

    - The docs have a detailed page on [Environment Variables][docs-environment] for reference.

    !!! note "Firewalled ports"

        You may need to open ports `25`, `587` and `465` on the firewall. For example, with the firewall `ufw`, run:

        ```sh
        ufw allow 25
        ufw allow 587
        ufw allow 465
        ```

4. Configure your DNS service to use an MX record for the _hostname_ (eg: `mail`) you configured in the previous step and add the [SPF][docs-spf] TXT record.

    If you manually manage the DNS zone file for the domain, it would look something like this:

    ```txt
    mail      IN  A   10.11.12.13

    ; mail-server for example.com
        3600  IN  MX  1  mail.example.com.

    ; Add SPF record
              IN TXT "v=spf1 mx ~all"
    ```

    Then don't forget to change the serial number and to restart the service.

5. [Generate DKIM keys][docs-dkim] for your domain via `./setup.sh config dkim`.

    Copy the content of the file `docker-data/dms/config/opendkim/keys/example.com/mail.txt` and add it to your DNS records as a TXT like SPF was handled above.

    I use [bind9](https://github.com/docker-scripts/bind9) for managing my domains, so I just paste it on `example.com.db`:

    ```txt
    mail._domainkey IN      TXT     ( "v=DKIM1; h=sha256; k=rsa; "
            "p=MIIBIjANBgkqhkiG9w0BAQEFACAQ8AMIIBCgKCAQEAaH5KuPYPSF3Ppkt466BDMAFGOA4mgqn4oPjZ5BbFlYA9l5jU3bgzRj3l6/Q1n5a9lQs5fNZ7A/HtY0aMvs3nGE4oi+LTejt1jblMhV/OfJyRCunQBIGp0s8G9kIUBzyKJpDayk2+KJSJt/lxL9Iiy0DE5hIv62ZPP6AaTdHBAsJosLFeAzuLFHQ6USyQRojefqFQtgYqWQ2JiZQ3"
            "iqq3bD/BVlwKRp5gH6TEYEmx8EBJUuDxrJhkWRUk2VDl1fqhVBy8A9O7Ah+85nMrlOHIFsTaYo9o6+cDJ6t1i6G1gu+bZD0d3/3bqGLPBQV9LyEL1Rona5V7TJBGg099NQkTz1IwIDAQAB" )  ; ----- DKIM key mail for example.com
    ```

6. Get an SSL certificate, [we have a guide for you here][docs-ssl] (_Let's Encrypt_ is a popular service to get free SSL certificates).

7. Start `docker-mailserver` and check the terminal output for any errors: `docker-compose up`.

8. Create email accounts and aliases:

    !!! example "With `SPOOF_PROTECTION=0`"

        ```sh
        ./setup.sh email add admin@example.com passwd123
        ./setup.sh email add info@example.com passwd123
        ./setup.sh alias add admin@example.com external-account@gmail.com
        ./setup.sh alias add info@example.com external-account@gmail.com
        ./setup.sh email list
        ./setup.sh alias list
        ```

        Aliases make sure that any email that comes to these accounts is forwarded to your third-party email address (`external-account@gmail.com`), where they are retrieved (_eg: via third-party web or mobile app_), instead of connecting directly to `docker-mailserer` with POP3 / IMAP.

    !!! example "With `SPOOF_PROTECTION=1`"

        ```sh
        ./setup.sh email add admin.gmail@example.com passwd123
        ./setup.sh email add info.gmail@example.com passwd123
        ./setup.sh alias add admin@example.com admin.gmail@example.com
        ./setup.sh alias add info@example.com info.gmail@example.com
        ./setup.sh alias add admin.gmail@example.com external-account@gmail.com
        ./setup.sh alias add info.gmail@example.com external-account@gmail.com
        ./setup.sh email list
        ./setup.sh alias list
        ```

        This extra step is required to avoid the `553 5.7.1 Sender address rejected: not owned by user` error (_the accounts used for submitting mail to Gmail are `admin.gmail@example.com` and `info.gmail@example.com`_)

9. Send some test emails to these addresses and make other tests. Once everything is working well, stop the container with `ctrl+c` and start it again as a daemon: `docker-compose up -d`.

[docs-ports]: ../../config/security/understanding-the-ports.md
[docs-setup-script]: ../../config/setup.sh.md
[docs-environment]: ../../config/environment.md
[docs-spf]: ../../config/best-practices/spf.md
[docs-dkim]: ../../config/best-practices/dkim.md
[docs-ssl]: ../../config/security/ssl.md#lets-encrypt-recommended

[github-issue-1405-comment]: https://github.com/docker-mailserver/docker-mailserver/issues/1405#issuecomment-590106498
