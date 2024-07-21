---
title: 'Tutorials | Mail Server behind a Proxy'
---

## Using a Reverse Proxy

Guidance is provided via a Traefik config example, however if you're only familiar with configuring a reverse proxy for web services there are some differences to keep in mind.

- A security concern where preserving the client IP is important but needs to be handled at Layer 4 (TCP).
- TLS will be handled differently due protocols like STARTTLS and the need to comply with standards for interoperability with other MTAs.
- The ability to route the same port to different containers by FQDN can be limited.

This reduces many of the benefits for why you might use a reverse proxy, but they can still be useful.

Some deployments may require a service to route traffic (kubernetes) when deploying, in which case the below advice is important to understand well.

The guide here has also been adapted for [our Kubernetes docs][docs::kubernetes].

## What can go wrong?

Without a reverse proxy involved, a service is typically aware of the client IP for a connection.

However when a reverse proxy routes the connection this information can be lost, and the proxied service mistakenly treats the client IP as the reverse proxy handling the connection.

- That can be problematic when the client IP is meaningful information for the proxied service to act upon, especially when it [impacts security](#security-concerns).
- The [PROXY protocol][networking::spec:proxy-protocol] is a well established solution to preserve the client IP when both the proxy and service have enabled the support.

??? abstract "Technical Details - HTTP vs TCP proxying"

    A key difference for how the network is proxied relates to the [OSI Model][networking::osi-model]:

    - Layer 7 (_Application layer protocols: SMTP / IMAP / HTTP / etc_)
    - Layer 4 (_Transport layer protocols: TCP / UDP_)

    When working with Layer 7 and a protocol like HTTP, it is possible to inspect a protocol header like [`Forwarded`][networking::http-header::forwarded] (_or it's predecessor: [`X-Forwarded-For`][networking::http-header::x-forwarded-for]_). At a lower level with Layer 4, that information is not available and we are routing traffic agnostic to the application protocol being proxied.

    A proxy can prepend the [PROXY protocol][networking::spec:proxy-protocol] header to the TCP/UDP connection as it is routed to the service, which must be configured to be compatible with PROXY protocol (_often this adds a restriction that connections must provide the header, otherwise they're rejected_).

    Beyond your own proxy, traffic may be routed in the network by other means that would also rewrite this information such as Docker's own network management via `iptables` and `userland-proxy` (NAT). The PROXY header ensures the original source and destination IP addresses, along with their ports is preserved across transit.

## Configuration

### Reverse Proxy

The below guidance is focused on configuring [Traefik][traefik-web], but the advice should be roughly applicable elsewhere (_eg: [NGINX][nginx-docs::proxyprotocol], [Caddy][caddy::plugin::l4]_).

- Support requires the capability to proxy TCP (Layer 4) connections with PROXY protocol enabled for the upstream (DMS). The upstream must also support enabling PROXY protocol (_which for DMS services rejects any connection not using the protocol_).
- TLS should not be terminated at the proxy, that should be delegated to DMS (_which should be configured with the TLS certs_). Reasoning is covered under the [ports section](#ports).

???+ example "Traefik service"

    The Traefik service config is fairly standard, just define the necessary entrypoints:

    ```yaml title="compose.yaml"
    services:
      reverse-proxy:
        image: docker.io/traefik:latest # 2.10 / 3.0
        # CAUTION: In production you should configure the Docker API endpoint securely:
        # https://doc.traefik.io/traefik/providers/docker/#docker-api-access
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
        command:
          # Docker provider config:
          - --providers.docker=true
          - --providers.docker.exposedbydefault=false
          # DMS ports you want to proxy:
          - --entryPoints.mail-smtp.address=:25
          - --entryPoints.mail-submission.address=:587
          - --entryPoints.mail-submissions.address=:465
          - --entryPoints.mail-imap.address=:143
          - --entryPoints.mail-imaps.address=:993
          - --entryPoints.mail-pop3.address=:110
          - --entryPoints.mail-pop3s.address=:995
          - --entryPoints.mail-managesieve.address=:4190
        # Publish external access ports mapped to traefik entrypoint ports:
        ports:
          - "25:25"
          - "587:587"
          - "465:465"
          - "143:143"
          - "993:993"
          - "110:110"
          - "995:995"
          - "4190:4190"
        # An IP is assigned here for other services (Dovecot) to trust for PROXY protocol:
        networks:
          default:
            ipv4_address: 172.16.42.2

    # Specifying a subnet to assign a fixed container IP to the reverse proxy:
    networks:
      default:
        name: my-network
        ipam:
          config:
            - subnet: "172.16.42.0/24"
    ```

    !!! note "Extra considerations"

        - [`--providers.docker.network=my-network`][traefik-docs::provider-docker::network] is useful when there is more than one network to consider.
        - If your deployment has any other hops (an edge proxy, load balancer, etc) between the reverse proxy and the client, you'll need PROXY protocol support throughout that chain. For Traefik this additionally requires [enabling PROXY protocol on your entry points][traefik-docs::entrypoint::proxyprotocol].

???+ example "Traefik labels for DMS"

    ```yaml title="compose.yaml"
    services:
      dms:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        hostname: mail.example.com
        labels:
          - traefik.enable=true

          # These are examples, configure the equivalent for any additional ports you proxy.
          # Explicit TLS (STARTTLS):
          - traefik.tcp.routers.mail-smtp.rule=HostSNI(`*`)
          - traefik.tcp.routers.mail-smtp.entrypoints=smtp
          - traefik.tcp.routers.mail-smtp.service=smtp
          - traefik.tcp.services.mail-smtp.loadbalancer.server.port=25
          - traefik.tcp.services.mail-smtp.loadbalancer.proxyProtocol.version=2

          # Implicit TLS is no different, except for optional HostSNI support:
          - traefik.tcp.routers.mail-submissions.rule=HostSNI(`*`)
          - traefik.tcp.routers.mail-submissions.entrypoints=smtp-submissions
          - traefik.tcp.routers.mail-submissions.service=smtp-submissions
          - traefik.tcp.services.mail-submissions.loadbalancer.server.port=465
          - traefik.tcp.services.mail-submissions.loadbalancer.proxyProtocol.version=2
          # NOTE: Optionally match by SNI rule, this requires TLS passthrough (not compatible with STARTTLS):
          #- traefik.tcp.routers.mail-submissions.rule=HostSNI(`mail.example.com`)
          #- traefik.tcp.routers.mail-submissions.tls.passthrough=true
    ```

    !!! note "PROXY protocol compatibility"

        Only TCP routers support enabling PROXY Protocol (via [`proxyProtocol.version=2`][traefik-docs::service-tcp::proxyprotocol])

        Postfix and Dovecot are both compatible with PROXY protocol v1 and v2.

#### Ports

??? abstract "Technical Details - Ports (Traefik config)"

    !!! info "Explicit TLS (STARTTLS)"

        **Service Ports:** `mail-smtp` (25), `mail-submission` (587), `mail-imap` (143), `mail-pop3` (110), `mail-managesieve` (4190)

        ---

        - [Traefik expects the TCP router to not enable TLS][traefik-docs::router-tcp::server-first-protocols] (_see "Server First protocols"_) for these connections. They begin in plaintext and potentially upgrade the connection to TLS, Traefik has no involvement in STARTTLS.
        - Without an initial TLS connection, the [`HostSNI` router rule is not usable][traefik-docs::router-tcp::host-sni] (_see "HostSNI & TLS"_). This limits routing flexibility for these ports (_eg: routing these ports by the FQDN to different DMS containers_).

    !!! info "Implicit TLS"

        **Service Ports:** `mail-submissions` (465), `mail-imaps` (993), `mail-pop3s` (995)

        ---

        The `HostSNI` router rule could specify the DMS FQDN instead of `*`:

        - This requires the router to have TLS enabled, so that Traefik can inspect the server name sent by the client.
        - Traefik can only match the SNI to `*` when the client does not provide a server name. Some clients must explicitly opt-in, such as CLI clients `openssl` (`-servername`) and `swaks` (`--tls-sni`).
        - Add [`tls.passthrough=true` to the router][traefik-docs::router-tcp::passthrough] (_this implicitly enables TLS_).
            - Traefik should not terminate TLS, decryption should occur within DMS instead when proxying to the same implicit TLS ports.
            - Passthrough ignores any certificates configured for Traefik; DMS must be configured with the certificates instead (_[DMS can use `acme.json` from Traefik][docs::tls::traefik]_).

        Unlike proxying HTTPS (port 443) to a container via HTTP (port 80), the equivalent for DMS service ports is not supported:

        - Port 25 must secure the connection via STARTTLS to be reached publicly.
        - STARTTLS ports requiring authentication for Postfix (587) and Dovecot (110, 143, 4190) are configured to only permit authentication over an encrypted connection.
        - Support would require routing the implicit TLS ports to their explicit TLS equivalent ports with auth restrictions removed. `tls.passthrough.true` would not be required, additionally port 25 would always be unencrypted (_if the proxy exclusively manages TLS/certs_), or unreachable by public MTAs attempting delivery if the proxy enables implicit TLS for this port.

### DMS (Postfix + Dovecot)

???+ example "Enable PROXY protocol on existing service ports"

    This can be handled via our config override support.

    ---

    Postfix via [`postfix-master.cf`][docs::overrides::postfix]:

    ```cf title="docker-data/dms/config/postfix-master.cf"
    smtp/inet/postscreen_upstream_proxy_protocol=haproxy
    submission/inet/smtpd_upstream_proxy_protocol=haproxy
    submissions/inet/smtpd_upstream_proxy_protocol=haproxy
    ```

    [`postscreen_upstream_proxy_protocol`][postfix-docs::settings::postscreen_upstream_proxy_protocol] and [`smtpd_upstream_proxy_protocol`][postfix-docs::settings::smtpd_upstream_proxy_protocol] both specify the protocol type used by a proxy. `haproxy` represents the PROXY protocol.

    ---

    Dovecot via [`dovecot.cf`][docs::overrides::dovecot]:

    ```cf  title="docker-data/dms/config/dovecot.cf"
    haproxy_trusted_networks = 172.16.42.2

    service imap-login {
      inet_listener imap {
        haproxy = yes
      }

      inet_listener imaps {
        haproxy = yes
      }
    }

    service pop3-login {
      inet_listener pop3 {
        haproxy = yes
      }

      inet_listener pop3s {
        haproxy = yes
      }
    }

    service managesieve-login {
      inet_listener sieve {
        haproxy = yes
      }
    }
    ```

    - [`haproxy_trusted_networks`][dovecot-docs::settings::haproxy-trusted-networks] must reference the reverse proxy IP, or a wider subnet using CIDR notation.
    - [`haproxy = yes`][dovecot-docs::service-config::haproxy] for the TCP listeners of each login service.

!!! warning "Internal traffic (_within the network or DMS itself_)"

    - Direct connections to DMS from other containers within the internal network will be rejected when they don't provide the required PROXY header.
    - This can also affect services running within the DMS container itself if they attempt to make a connection and aren't PROXY protocol capable.

    ---

    A solution is to configure alternative service ports that offer PROXY protocol support (as shown next).

    Alternatively routing connections to DMS through the local reverse proxy via [DNS query rewriting][gh-dms::dns-rewrite-example] can work too.

??? example "Configuring services with separate ports for PROXY protocol"

    In this example we'll take the original service ports and add `10000` for the new PROXY protocol service ports.

    Traefik labels will need to update their service ports accordingly (eg: `.loadbalancer.server.port=10465`).

    ---

    Postfix config now requires [our `user-patches.sh` support][docs::overrides::user-patches] to add new services in `/etc/postfix/master.cf`:

    ```bash title="docker-data/dms/config/user-patches.sh"
    #!/bin/bash

    # Duplicate the config for the submission(s) service ports (587 / 465) with adjustments for the PROXY ports (10587 / 10465) and `syslog_name` setting:
    postconf -Mf submission/inet | sed -e s/^submission/10587/ -e 's/submission/submission-proxyprotocol/' >> /etc/postfix/master.cf
    postconf -Mf submissions/inet | sed -e s/^submissions/10465/ -e 's/submissions/submissions-proxyprotocol/' >> /etc/postfix/master.cf
    # Enable PROXY Protocol support for these new service variants:
    postconf -P 10587/inet/smtpd_upstream_proxy_protocol=haproxy
    postconf -P 10465/inet/smtpd_upstream_proxy_protocol=haproxy

    # Create a variant for port 25 too (NOTE: Port 10025 is already assigned in DMS to Amavis):
    postconf -Mf smtp/inet | sed -e s/^smtp/12525/ >> /etc/postfix/master.cf
    # Enable PROXY Protocol support (different setting as port 25 is handled via postscreen), optionally configure a `syslog_name` to distinguish in logs:
    postconf -P 12525/inet/postscreen_upstream_proxy_protocol=haproxy 12525/inet/syslog_name=smtp-proxyprotocol
    ```

    Supporting port 25 with an additional PROXY protocol port will also require a `postfix-main.cf` override line for `postscreen` to work correctly:

    ```cf  title="docker-data/dms/config/postfix-main.cf"
    postscreen_cache_map = proxy:btree:$data_directory/postscreen_cache
    ```

    ---

    Dovecot is mostly the same as before:

    - A new service name instead of targeting one to modify.
    - Add the new port assignment.
    - Set [`ssl = yes`][dovecot-docs::service-config::ssl] when implicit TLS is needed.

    ```cf  title="docker-data/dms/config/dovecot.cf"
    haproxy_trusted_networks = 172.16.42.2

    service imap-login {
      inet_listener imap-proxied {
        haproxy = yes
        port = 10143
      }

      inet_listener imaps-proxied {
        haproxy = yes
        port = 10993
        ssl = yes
      }
    }

    service pop3-login {
      inet_listener pop3-proxied {
        haproxy = yes
        port = 10110
      }

      inet_listener pop3s-proxied {
        haproxy = yes
        port = 10995
        ssl = yes
      }
    }

    service managesieve-login {
      inet_listener sieve-proxied {
        haproxy = yes
        port = 14190
      }
    }
    ```

## Verification

Send an email through the reverse proxy. If you do not use the DNS query rewriting approach, you'll need to do this from an external client.

??? example "Sending a generic test mail through `swaks` CLI"

    Run a `swaks` command and then check your DMS logs for the expected client IP, it should no longer be using the reverse proxy IP.

    ```bash
    # NOTE: It is common to find port 25 is blocked from outbound connections, you may only be able to test the submission(s) ports.
    swaks --helo not-relevant.test --server mail.example.com --port 25 -tls --from hello@not-relevant.test --to user@example.com
    ```

    - You can specify the `--server` as the DMS FQDN or an IP address, where either should connect to the reverse proxy service.
    - `not-relevant.test` technically may be subject to some tests, at least for port 25. With the submission(s) ports those should be exempt.
    - `-tls` will use STARTTLS on port 25, you can exclude it to send unencrypted, but it would still go through the same port/route being tested.
    - To test the submission ports use `--port 587 -tls` or `--port 465 -tlsc` with your credentials `--auth-user user@example.com --auth-password secret`
    - Add `--tls-sni mail.example.com` if you have configured `HostSNI` in Traefik router rules (_SNI routing is only valid for implicit TLS ports_).

??? warning "Do not rely on local testing alone"

    Testing from the Docker host technically works, however the IP is likely subject to more manipulation via `iptables` than an external client.

    The IP will likely appear as from the gateway IP of the Docker network associated to the reverse proxy, where that gateway IP then becomes the client IP when writing the PROXY protocol header.

## Security concerns

### Forgery

Since the PROXY protocol sends a header with the client IP rewritten for software to use instead, this could be abused by bad actors.

Software on the receiving end of the connection often supports configuring an IP or CIDR range of clients to trust receiving the PROXY protocol header from.

??? warning "Risk exposure"

    If you trust more than the reverse proxy IP, you must consider the risk exposure:

    - Any container within the network that is compromised could impersonate another IP (_container or external client_) which may have been configured to have additional access/exceptions granted.
    - If the reverse proxy is on a separate network/host than DMS, exposure of the PROXY protocol enabled ports outside the network increases the importance of narrowing trust. For example with the [known IPv6 to subnet Gateway IP routing gotcha][docs::ipv6::security-risks] in Docker, trusting the entire subnet DMS belongs to would wrongly trust external clients that have the subnet Gateway IP to impersonate any client IP.
    - There is a [known risk with Layer 2 switching][docker::networking::l2-switch-gotcha] (_applicable to VPC networks, impact varies by cloud vendor_):
        - Neighbouring hosts can indirectly route to ports published on the interfaces of a separate host system that shouldn't be reachable (_eg: localhost `127.0.0.1`, or a private subnet `172.16.0.0/12`_).
        - The scope of this in Docker is limited to published ports only when Docker uses `iptables` with the kernel tunable `sysctl net.ipv4.ip_forward=1` (enabled implicitly). Port access is via `HOST:CONTAINER` ports published to their respective interface(s), that includes the container IP + port.

    While some concerns raised above are rather specific, these type of issues aren't exclusive to Docker and difficult to keep on top of as software is constantly changing. Limit the trusted networks where possible.

??? warning "Postfix has no concept of trusted proxies"

    Postfix does not appear to have a way to configure trusted proxies like Dovecot does (`haproxy_trusted_networks`).

    [`postscreen_access_list`][postfix-docs::settings::postscreen_access_list] (_or [`smtpd_client_restrictions`][postfix-docs::settings::smtpd_client_restrictions] with [`check_client_access`][postfix-docs::settings::check_client_access] for ports 587/465_) can both restrict access by IP via a [CIDR lookup table][postfix-docs::config-table::cidr], however the client IP is already rewritten at this point via PROXY protocol.

    Thus those settings cannot be used for restricting access to only trusted proxies, only to the actual clients.

    A similar setting [`mynetworks`][postfix-docs::settings::mynetworks] / [`PERMIT_DOCKER`][docs::env::permit_docker] manages elevated trust for bypassing security restrictions. While it is intended for trusted clients, it has no relevance to trusting proxies for the same reasons.

### Monitoring

While PROXY protocol works well with the reverse proxy, you may have some containers internally that interact with DMS on behalf of multiple clients.

??? example "Roundcube + Fail2Ban"

    You may have other services with functionality like an API to send mail through DMS that likewise delegates credentials through DMS.

    Roundcube is an example of this where authentication is delegated to DMS, which introduces the same concern with loss of client IP.

    - While this service does implement some support for preserving the client IP, it is limited.
    - This may be problematic when monitoring services like Fail2Ban are enabled that scan logs for multiple failed authentication attempts which triggers a ban on the shared IP address.

    You should adjust configuration of these monitoring services to monitor for auth failures from those services directly instead, adding an exclusion for that service IP from any DMS logs monitored (_but be mindful of PROXY header forgery risks_).

[docs::kubernetes]: ../../config/advanced/kubernetes.md#using-the-proxy-protocol

[docs::overrides::dovecot]: ../../config/advanced/override-defaults/dovecot.md
[docs::overrides::postfix]: ../../config/advanced/override-defaults/postfix.md
[docs::overrides::user-patches]: ../../config/advanced/override-defaults/user-patches.md
[docs::ipv6::security-risks]: ../../config/advanced/ipv6.md#what-can-go-wrong
[docs::tls::traefik]: ../../config/security/ssl.md#traefik
[docs::env::permit_docker]: ../../config/environment.md#permit_docker
[gh-dms::dns-rewrite-example]: https://github.com/docker-mailserver/docker-mailserver/issues/3866#issuecomment-1928877236

[nginx-docs::proxyprotocol]: https://docs.nginx.com/nginx/admin-guide/load-balancer/using-proxy-protocol
[caddy::plugin::l4]: https://github.com/mholt/caddy-l4

[traefik-web]: https://traefik.io
[traefik-docs::entrypoint::proxyprotocol]: https://doc.traefik.io/traefik/routing/entrypoints/#proxyprotocol
[traefik-docs::provider-docker::network]: https://doc.traefik.io/traefik/providers/docker/#network
[traefik-docs::router-tcp::server-first-protocols]: https://doc.traefik.io/traefik/routing/routers/#entrypoints_1
[traefik-docs::router-tcp::host-sni]: https://doc.traefik.io/traefik/routing/routers/#rule_1
[traefik-docs::router-tcp::passthrough]: https://doc.traefik.io/traefik/routing/routers/#passthrough
[traefik-docs::service-tcp::proxyprotocol]:https://doc.traefik.io/traefik/routing/services/#proxy-protocol

[dovecot-docs::settings::haproxy-trusted-networks]: https://doc.dovecot.org/settings/core/#core_setting-haproxy_trusted_networks
[dovecot-docs::service-config::haproxy]: https://doc.dovecot.org/configuration_manual/service_configuration/#haproxy-v2-2-19
[dovecot-docs::service-config::ssl]: https://doc.dovecot.org/configuration_manual/service_configuration/#ssl

[postfix-docs::config-table::cidr]: https://www.postfix.org/cidr_table.5.html
[postfix-docs::settings::check_client_access]: https://www.postfix.org/postconf.5.html#check_client_access
[postfix-docs::settings::mynetworks]: https://www.postfix.org/postconf.5.html#mynetworks
[postfix-docs::settings::postscreen_access_list]: https://www.postfix.org/postconf.5.html#postscreen_access_list
[postfix-docs::settings::postscreen_upstream_proxy_protocol]: https://www.postfix.org/postconf.5.html#postscreen_upstream_proxy_protocol
[postfix-docs::settings::smtpd_client_restrictions]: https://www.postfix.org/postconf.5.html#smtpd_client_restrictions
[postfix-docs::settings::smtpd_upstream_proxy_protocol]: https://www.postfix.org/postconf.5.html#smtpd_upstream_proxy_protocol

[docker::networking::l2-switch-gotcha]: https://github.com/moby/moby/issues/45610
[networking::spec:proxy-protocol]: https://github.com/haproxy/haproxy/blob/master/doc/proxy-protocol.txt
[networking::http-header::x-forwarded-for]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-For
[networking::http-header::forwarded]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Forwarded
[networking::osi-model]: https://www.cloudflare.com/learning/ddos/glossary/open-systems-interconnection-model-osi/
