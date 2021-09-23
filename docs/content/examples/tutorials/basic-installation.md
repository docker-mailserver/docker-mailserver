---
title: 'Tutorials | Basic Installation'
---

## Building a Simple Mail-Server

!!! warning
    Adding the docker network's gateway to the list of trusted hosts, e.g. using the `network` or `connected-networks` option, can create an [**open relay**](https://en.wikipedia.org/wiki/Open_mail_relay), for instance [if IPv6 is enabled on the host machine but not in Docker][github-issue-1405-comment].

We are going to use this docker based mailserver:

- First create a directory for `docker-mailserver` to store data in, and get the `setup.sh` script:

    ```sh
    mkdir -p /var/ds/mail.example.com
    cd /var/ds/mail.example.com/

    curl -o setup.sh \
        https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/setup.sh
    chmod a+x ./setup.sh
    ```

- Create the file `docker-compose.yml` with a content like this:

    !!! example

        ```yaml
        version: '3.8'

        services:
          mailserver:
            image: docker.io/mailserver/docker-mailserver:latest
            container_name: mailserver
            hostname: mail
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
                - /etc/localtime:/etc/localtime:ro
                - /var/ds/wsproxy/letsencrypt/:/etc/letsencrypt/
            environment:
                - PERMIT_DOCKER=network
                - SSL_TYPE=letsencrypt
                - ONE_DIR=1
                - DMS_DEBUG=0
                - SPOOF_PROTECTION=0
                - REPORT_RECIPIENT=1
                - ENABLE_SPAMASSASSIN=0
                - ENABLE_CLAMAV=0
                - ENABLE_FAIL2BAN=1
                - ENABLE_POSTGREY=0
            cap_add:
                - NET_ADMIN
                - SYS_PTRACE
        ```

    For more details about the environment variables that can be used, and their meaning and possible values, check also these:

    - [Environment Variables][docs-environment]
    - [`mailserver.env` file][github-file-dotenv]

    Make sure to set the proper `domainname` that you will use for the emails. We forward only SMTP ports (not POP3 and IMAP) because we are not interested in accessing the mail-server directly (from a client). We also use these settings:

    - `PERMIT_DOCKER=network` because we want to send emails from other docker containers.
    - `SSL_TYPE=letsencrypt` because we will manage SSL certificates with letsencrypt.

- We need to open ports `25`, `587` and `465` on the firewall:

    ```sh
    ufw allow 25
    ufw allow 587
    ufw allow 465
    ```

    On your server you may have to do it differently.

- Pull the docker image: `docker pull mailserver/docker-mailserver:latest`

- Now generate the DKIM keys with `./setup.sh config dkim` and copy the content of the file `docker-data/dms/config/opendkim/keys/example.com/mail.txt` on the domain zone configuration at the DNS server. I use [bind9](https://github.com/docker-scripts/bind9) for managing my domains, so I just paste it on `example.com.db`:

    ```txt
    mail._domainkey IN      TXT     ( "v=DKIM1; h=sha256; k=rsa; "
            "p=MIIBIjANBgkqhkiG9w0BAQEFACAQ8AMIIBCgKCAQEAaH5KuPYPSF3Ppkt466BDMAFGOA4mgqn4oPjZ5BbFlYA9l5jU3bgzRj3l6/Q1n5a9lQs5fNZ7A/HtY0aMvs3nGE4oi+LTejt1jblMhV/OfJyRCunQBIGp0s8G9kIUBzyKJpDayk2+KJSJt/lxL9Iiy0DE5hIv62ZPP6AaTdHBAsJosLFeAzuLFHQ6USyQRojefqFQtgYqWQ2JiZQ3"
            "iqq3bD/BVlwKRp5gH6TEYEmx8EBJUuDxrJhkWRUk2VDl1fqhVBy8A9O7Ah+85nMrlOHIFsTaYo9o6+cDJ6t1i6G1gu+bZD0d3/3bqGLPBQV9LyEL1Rona5V7TJBGg099NQkTz1IwIDAQAB" )  ; ----- DKIM key mail for example.com
    ```

- Add these configurations as well on the same file on the DNS server:

    ```txt
    mail      IN  A   10.11.12.13

    ; mail-server for example.com
        3600  IN  MX  1  mail.example.com.

    ; Add SPF record
              IN TXT "v=spf1 mx ~all"
    ```

    Then don't forget to change the serial number and to restart the service.

- Get an SSL certificate from letsencrypt. I use [wsproxy](https://gitlab.com/docker-scripts/wsproxy) for managing SSL letsencrypt certificates of my domains:

    ```sh
    cd /var/ds/wsproxy
    ds domains-add mail mail.example.com
    ds get-ssl-cert external-account@gmail.com mail.example.com --test
    ds get-ssl-cert external-account@gmail.com mail.example.com
    ```

    Now the certificates will be available on `/var/ds/wsproxy/letsencrypt/live/mail.example.com`.

- Start `docker-mailserver` and check for any errors:

    ```sh
    apt install docker-compose
    docker-compose up mailserver
    ```

- Create email accounts and aliases with `SPOOF_PROTECTION=0`:

    ```sh
    ./setup.sh email add admin@example.com passwd123
    ./setup.sh email add info@example.com passwd123
    ./setup.sh alias add admin@example.com external-account@gmail.com
    ./setup.sh alias add info@example.com external-account@gmail.com
    ./setup.sh email list
    ./setup.sh alias list
    ```

    Aliases make sure that any email that comes to these accounts is forwarded to my real email address, so that I don't need to use POP3/IMAP in order to get these messages. Also no anti-spam and anti-virus software is needed, making the mail-server lighter.

- Or create email accounts and aliases with `SPOOF_PROTECTION=1`:

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

    This extra step is required to avoid the `553 5.7.1 Sender address rejected: not owned by user` error (the account used for setting up Gmail is `admin.gmail@example.com` and `info.gmail@example.com` )

- Send some test emails to these addresses and make other tests. Then stop the container with `ctrl+c` and start it again as a daemon: `docker-compose up -d mailserver`.

- Now save on Moodle configuration the SMTP settings and test by trying to send some messages to other users:

    - **SMTP hosts**: `mail.example.com:465`
    - **SMTP security**: `SSL`
    - **SMTP username**: `info@example.com`
    - **SMTP password**: `passwd123`

[docs-environment]: ../../config/environment.md
[github-file-dotenv]: https://github.com/docker-mailserver/docker-mailserver/blob/master/mailserver.env
[github-issue-1405-comment]: https://github.com/docker-mailserver/docker-mailserver/issues/1405#issuecomment-590106498
