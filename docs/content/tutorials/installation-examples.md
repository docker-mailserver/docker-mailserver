---
title: 'Tutorials | Installation Examples'
---

## Building a Simple Mailserver

!!! warning
    Adding the docker network's gateway to the list of trusted hosts, e.g. using the `network` or `connected-networks` option, can create an [**open relay**](https://en.wikipedia.org/wiki/Open_mail_relay), for instance [if IPv6 is enabled on the host machine but not in Docker][github-issue-1405-comment].

We are going to use this docker based mailserver:

- First create a directory for the mailserver and get the setup script:

    ```sh
    mkdir -p /var/ds/mail.example.org
    cd /var/ds/mail.example.org/

    curl -o setup.sh \
        https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/setup.sh
    chmod a+x ./setup.sh
    ```

- Create the file `docker-compose.yml` with a content like this:

    ```yaml
    version: '2'

    services:
      mail:
        image: tvial/docker-mailserver:latest
        hostname: mail
        domainname: example.org
        container_name: mail
        ports:
        - "25:25"
        - "587:587"
        - "465:465"
        volumes:
        - ./data/:/var/mail/
        - ./state/:/var/mail-state/
        - ./config/:/tmp/docker-mailserver/
        - /var/ds/wsproxy/letsencrypt/:/etc/letsencrypt/
        environment:
        - PERMIT_DOCKER=network
        - SSL_TYPE=letsencrypt
        - ONE_DIR=1
        - DMS_DEBUG=1
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

    - [Environtment Variables][github-file-env]
    - [`mailserver.env` file][github-file-dotenv]

    Make sure to set the proper `domainname` that you will use for the emails. We forward only SMTP ports (not POP3 and IMAP) because we are not interested in accessing the mailserver directly (from a client).  We also use these settings:

    - `PERMIT_DOCKER=network` because we want to send emails from other docker containers.
    - `SSL_TYPE=letsencrypt` because we will manage SSL certificates with letsencrypt.

- We need to open ports `25`, `587` and `465` on the firewall:

    ```sh
    ufw allow 25
    ufw allow 587
    ufw allow 465
    ```

    On your server you may have to do it differently.

- Pull the docker image: `docker pull tvial/docker-mailserver:latest`

- Now generate the DKIM keys with `./setup.sh config dkim` and copy the content of the file `config/opendkim/keys/domain.tld/mail.txt` on the domain zone configuration at the DNS server. I use [bind9](https://github.com/docker-scripts/bind9) for managing my domains, so I just paste it on `example.org.db`:

    ```txt
    mail._domainkey IN      TXT     ( "v=DKIM1; h=sha256; k=rsa; "
            "p=MIIBIjANBgkqhkiG9w0BAQEFACAQ8AMIIBCgKCAQEAaH5KuPYPSF3Ppkt466BDMAFGOA4mgqn4oPjZ5BbFlYA9l5jU3bgzRj3l6/Q1n5a9lQs5fNZ7A/HtY0aMvs3nGE4oi+LTejt1jblMhV/OfJyRCunQBIGp0s8G9kIUBzyKJpDayk2+KJSJt/lxL9Iiy0DE5hIv62ZPP6AaTdHBAsJosLFeAzuLFHQ6USyQRojefqFQtgYqWQ2JiZQ3"
            "iqq3bD/BVlwKRp5gH6TEYEmx8EBJUuDxrJhkWRUk2VDl1fqhVBy8A9O7Ah+85nMrlOHIFsTaYo9o6+cDJ6t1i6G1gu+bZD0d3/3bqGLPBQV9LyEL1Rona5V7TJBGg099NQkTz1IwIDAQAB" )  ; ----- DKIM key mail for example.org
    ```

- Add these configurations as well on the same file on the DNS server:

    ```txt
    mail      IN  A   10.11.12.13

    ; mailservers for example.org
        3600  IN  MX  1  mail.example.org.

    ; Add SPF record
              IN TXT "v=spf1 mx ~all"
    ```

    Then don't forget to change the serial number and to restart the service.

- Get an SSL certificate from letsencrypt. I use [wsproxy](https://github.com/docker-scripts/wsproxy) for managing SSL letsencrypt certificates of my domains:

    ```sh
    cd /var/ds/wsproxy
    ds domains-add mail mail.example.org
    ds get-ssl-cert myemail@gmail.com mail.example.org --test
    ds get-ssl-cert myemail@gmail.com mail.example.org
    ```

    Now the certificates will be available on `/var/ds/wsproxy/letsencrypt/live/mail.example.org`.

- Start the mailserver and check for any errors:

    ```sh
    apt install docker-compose
    docker-compose up mail
    ```

- Create email accounts and aliases with `SPOOF_PROTECTION=0`:

    ```sh
    ./setup.sh email add admin@example.org passwd123
    ./setup.sh email add info@example.org passwd123
    ./setup.sh alias add admin@example.org myemail@gmail.com
    ./setup.sh alias add info@example.org myemail@gmail.com
    ./setup.sh email list
    ./setup.sh alias list
    ```

    Aliases make sure that any email that comes to these accounts is forwarded to my real email address, so that I don't need to use POP3/IMAP in order to get these messages. Also no anti-spam and anti-virus software is needed, making the mailserver lighter.

- Or create email accounts and aliases with `SPOOF_PROTECTION=1`:

    ```sh
    ./setup.sh email add admin.gmail@example.org passwd123
    ./setup.sh email add info.gmail@example.org passwd123
    ./setup.sh alias add admin@example.org admin.gmail@example.org
    ./setup.sh alias add info@example.org info.gmail@example.org
    ./setup.sh alias add admin.gmail@example.org myemail@gmail.com
    ./setup.sh alias add info.gmail@example.org myemail@gmail.com
    ./setup.sh email list
    ./setup.sh alias list
    ```

    This extra step is required to avoid the `553 5.7.1 Sender address rejected: not owned by user` error (the account used for setting up gmail is `admin.gmail@example.org` and `info.gmail@example.org` )

- Send some test emails to these addresses and make other tests. Then stop the container with `ctrl+c` and start it again as a daemon: `docker-compose up -d mail`.

- Now save on Moodle configuration the SMTP settings and test by trying to send some messages to other users:

    - **SMTP hosts**: `mail.example.org:465`
    - **SMTP security**: `SSL`
    - **SMTP username**: `info@example.org`
    - **SMTP password**: `passwd123`

## Using `docker-mailserver` behind a Proxy

### Information

If you are hiding your container behind a proxy service you might have discovered that the proxied requests from now on contain the proxy IP as the request origin. Whilst this behavior is technical correct it produces certain problems on the containers behind the proxy as they cannot distinguish the real origin of the requests anymore.

To solve this problem on TCP connections we can make use of the [proxy protocol](https://www.haproxy.org/download/1.8/doc/proxy-protocol.txt). Compared to other workarounds that exist (`X-Forwarded-For` which only works for HTTP requests or `Tproxy` that requires you to recompile your kernel) the proxy protocol:

- It is protocol agnostic (can work with any layer 7 protocols, even when encrypted).
- It does not require any infrastructure changes.
- NAT-ing firewalls have no impact it.
- It is scalable.

There is only one condition: **both endpoints** of the connection MUST be compatible with proxy protocol.

Luckily `dovecot` and `postfix` are both Proxy-Protocol ready softwares so it depends only on your used reverse-proxy / loadbalancer.

### Configuration of the used Proxy Software

The configuration depends on the used proxy system. I will provide the configuration examples of [traefik v2](https://traefik.io/) using IMAP and SMTP with implicit TLS.

Feel free to add your configuration if you achived the same goal using different proxy software below:

??? "Traefik v2"

    Truncated configuration of traefik itself:

    ```yaml
    version: '3.7'
    services:
      reverse-proxy:
        image: traefik:v2.4
        container_name: docker-traefik
        restart: always
        command:
          - "--providers.docker"
          - "--providers.docker.exposedbydefault=false"
          - "--providers.docker.network=proxy"
          - "--entrypoints.web.address=:80"
          - "--entryPoints.websecure.address=:443"
          - "--entryPoints.smtp.address=:25"
          - "--entryPoints.smtp-ssl.address=:465"
          - "--entryPoints.imap-ssl.address=:993"
          - "--entryPoints.sieve.address=:4190"
        ports:
          - "25:25"
          - "465:465"
          - "993:993"
          - "4190:4190"
    [...]
    ```

    Truncated list of neccessary labels on the mailserver container:

    ```yaml
    version: '2'
    services:
      mail:
        image: tvial/docker-mailserver:release-v7.2.0
        restart: always
        networks:
          - proxy
        labels:
          - "traefik.enable=true"
          - "traefik.tcp.routers.smtp.rule=HostSNI(`*`)"
          - "traefik.tcp.routers.smtp.entrypoints=smtp"
          - "traefik.tcp.routers.smtp.service=smtp"
          - "traefik.tcp.services.smtp.loadbalancer.server.port=25"
          - "traefik.tcp.services.smtp.loadbalancer.proxyProtocol.version=1"
          - "traefik.tcp.routers.smtp-ssl.rule=HostSNI(`*`)"
          - "traefik.tcp.routers.smtp-ssl.entrypoints=smtp-ssl"
          - "traefik.tcp.routers.smtp-ssl.service=smtp-ssl"
          - "traefik.tcp.services.smtp-ssl.loadbalancer.server.port=465"
          - "traefik.tcp.services.smtp-ssl.loadbalancer.proxyProtocol.version=1"
          - "traefik.tcp.routers.imap-ssl.rule=HostSNI(`*`)"
          - "traefik.tcp.routers.imap-ssl.entrypoints=imap-ssl"
          - "traefik.tcp.routers.imap-ssl.service=imap-ssl"
          - "traefik.tcp.services.imap-ssl.loadbalancer.server.port=10993"
          - "traefik.tcp.services.imap-ssl.loadbalancer.proxyProtocol.version=2"
          - "traefik.tcp.routers.sieve.rule=HostSNI(`*`)"
          - "traefik.tcp.routers.sieve.entrypoints=sieve"
          - "traefik.tcp.routers.sieve.service=sieve"
          - "traefik.tcp.services.sieve.loadbalancer.server.port=4190"
    [...]
    ```

    Keep in mind that it is neccessary to use port `10993` here. More information below at `dovecot` configuration.

### Configuration of the Backend (`dovecot` and `postfix`)

The following changes can be achived completely by adding the content to the appropriate files by using the projects [function to overwrite config files][docs-optionalconfig].

Changes for `postfix` can be applied by adding the following content to `config/postfix-main.cf`:

```cf
postscreen_upstream_proxy_protocol = haproxy
```

and to `config/postfix-master.cf`:

```cf
submission/inet/smtpd_upstream_proxy_protocol=haproxy
smtps/inet/smtpd_upstream_proxy_protocol=haproxy
```

Changes for `dovecot` can be applied by adding the following content to `config/dovecot.cf`:

```cf
haproxy_trusted_networks = <your-proxy-ip>, <optional-cidr-notation>
haproxy_timeout = 3 secs
service imap-login {
  inet_listener imaps {
    haproxy = yes
    ssl = yes
    port = 10993
  }
}
```

!!! note
    Port `10993` is used here to avoid conflicts with internal systems like `postscreen` and `amavis` as they will exchange messages on the default port and obviously have a different origin then compared to the proxy.

[docs-optionalconfig]: ../advanced/optional-config.md
[github-file-env]: https://github.com/docker-mailserver/docker-mailserver/blob/master/ENVIRONMENT.md
[github-file-dotenv]: https://github.com/docker-mailserver/docker-mailserver/blob/master/mailserver.env
[github-issue-1405-comment]: https://github.com/docker-mailserver/docker-mailserver/issues/1405#issuecomment-590106498
