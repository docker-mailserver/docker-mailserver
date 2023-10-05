---
title: 'Tutorials | Mail Server behind a Proxy'
---

## Using DMS behind a Proxy

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

Feel free to add your configuration if you achieved the same goal using different proxy software below:

??? "Traefik v2"

    Truncated configuration of traefik itself:

    ```yaml
    services:
      reverse-proxy:
        image: docker.io/traefik:latest # v2.5
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

    Truncated list of necessary labels on the DMS container:

    ```yaml
    services:
      mailserver:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        container_name: mailserver
        hostname: mail.example.com
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
          - "traefik.tcp.routers.smtp-ssl.tls.passthrough=true"
          - "traefik.tcp.routers.smtp-ssl.service=smtp-ssl"
          - "traefik.tcp.services.smtp-ssl.loadbalancer.server.port=465"
          - "traefik.tcp.services.smtp-ssl.loadbalancer.proxyProtocol.version=1"
          - "traefik.tcp.routers.imap-ssl.rule=HostSNI(`*`)"
          - "traefik.tcp.routers.imap-ssl.entrypoints=imap-ssl"
          - "traefik.tcp.routers.imap-ssl.service=imap-ssl"
          - "traefik.tcp.routers.imap-ssl.tls.passthrough=true"
          - "traefik.tcp.services.imap-ssl.loadbalancer.server.port=10993"
          - "traefik.tcp.services.imap-ssl.loadbalancer.proxyProtocol.version=2"
          - "traefik.tcp.routers.sieve.rule=HostSNI(`*`)"
          - "traefik.tcp.routers.sieve.entrypoints=sieve"
          - "traefik.tcp.routers.sieve.service=sieve"
          - "traefik.tcp.services.sieve.loadbalancer.server.port=4190"
    [...]
    ```

    Keep in mind that it is necessary to use port `10993` here. More information below at `dovecot` configuration.

### Configuration of the Backend (`dovecot` and `postfix`)

The following changes can be achieved completely by adding the content to the appropriate files by using the projects [function to overwrite config files][docs-optionalconfig].

Changes for `postfix` can be applied by adding the following content to `docker-data/dms/config/postfix-main.cf`:

```cf
postscreen_upstream_proxy_protocol = haproxy
```

and to `docker-data/dms/config/postfix-master.cf`:

```cf
submission/inet/smtpd_upstream_proxy_protocol=haproxy
submissions/inet/smtpd_upstream_proxy_protocol=haproxy
```

Changes for `dovecot` can be applied by adding the following content to `docker-data/dms/config/dovecot.cf`:

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

[docs-optionalconfig]: ../../config/advanced/optional-config.md
