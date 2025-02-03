---
title: 'Use Cases | Binding outbound SMTP to a specific network'
hide:
  - toc
---

!!! warning "Advice not extensively tested"

    This configuration advice is a community contribution which has only been verified as a solution when using `network: host`, where you have direct access to the host interfaces.

    It may be applicable in other network modes if the container has control of the outbound IPs to bind to. This is not the case with bridge networks that typically bind to a private range network for containers which are bridged to a public interface via Docker.

If your Docker host is running multiple IPv4 and IPv6 IP-addresses, it may be beneficial to bind outgoing SMTP connections to specific IP-address / interface.

- When a mail is sent outbound from DMS, it greets the MTA it is connecting to with a EHLO (DMS FQDN) which might be verified against the IP resolved, and that a `PTR` record for that IP resolves an address back to the same IP.
- A similar check with SPF can be against the envelope-sender address which may verify a DNS record like MX / A is valid (_or a similar restriction check from an MTA like [Postfix has with `reject_unknown_sender`][gh-pr::3465::comment-restrictions]_).
- If the IP address is inconsistent for those connections from DMS, these DNS checks are likely to fail.

This can be configured by [overriding the default Postfix configurations][docs::overrides-postfix] DMS provides. Create `postfix-master.cf` and `postfix-main.cf` files for your config volume (`docker-data/dms/config`).

In `postfix-main.cf` you'll have to set the [`smtp_bind_address`][postfix-docs::smtp-bind-address-ipv4] and [`smtp_bind_address6`][postfix-docs::smtp-bind-address-ipv6]
to the respective IP-address on the server you want to use.

[docs::overrides-postfix]: ../../config/advanced/override-defaults/postfix.md
[postfix-docs::smtp-bind-address-ipv4]: https://www.postfix.org/postconf.5.html#smtp_bind_address
[postfix-docs::smtp-bind-address-ipv6]: https://www.postfix.org/postconf.5.html#smtp_bind_address6

!!! example

    === "Contributed solution"

        ```title="postfix-main.cf"
        smtp_bind_address = 198.51.100.42
        smtp_bind_address6 = 2001:DB8::42
        ```

        !!! bug "Inheriting the bind from `main.cf` can misconfigure services"

            One problem when setting `smtp_bind_address` in `main.cf` is that it will be inherited by any services in `master.cf` that extend the `smtp` transport. One of these is `smtp-amavis`, which is explicitly configured to listen / connect via loopback (localhost / `127.0.0.1`).

            A `postfix-master.cf` override can workaround that issue by ensuring `smtp-amavis` binds to the expected internal IP:

            ```title="postfix-master.cf"
            smtp-amavis/unix/smtp_bind_address=127.0.0.1
            smtp-amavis/unix/smtp_bind_address6=::1
            ```

    === "Alternative (unverified)"

        A potentially better solution might be to instead [explicitly set the `smtp_bind_address` override on the `smtp` transport service][gh-pr::3465::alternative-solution]:

        ```title="postfix-master.cf"
        smtp/inet/smtp_bind_address = 198.51.100.42
        smtp/inet/smtp_bind_address6 = 2001:DB8::42
        ```

        If that avoids the concern with `smtp-amavis`, you may still need to additionally override for the [`relay` transport][gh-src::postfix-master-cf::relay-transport] as well if you have configured DMS to relay mail.
        
    === "Bridged Networks"
    
        When your DMS container is using a bridge network, you'll instead need to restrict which IP address inbound and outbound traffic is routed through via the bridged interface.
        
        For inbound traffic, you may configure this at whatever scope is most appropriate for you:
        - **Daemon:** Change the default bind address configured in `/etc/docker/daemon.json` (default `0.0.0.0`)
        - **Network:** Assign the [`host_binding_ipv4` bridge driver option](https://docs.docker.com/engine/network/drivers/bridge/#default-host-binding-address) as shown in the below `compose.yaml` snippet.
        - **Container:** Provide an explicit IP address when publishing a port.
        
        For outbound traffic, the bridge network will use the default route.

        - [Manually route](https://github.com/moby/moby/issues/30053#issuecomment-1077041045) (Agnostic)
        - Docker networking supports a driver option `host_ipv4` to force the SNAT (source IP) that the container will route through.
            - This must belong to a valid network interface to be routed through it.
            - IPv6 support via `host_ipv6` [requires at least Docker v25](https://github.com/moby/moby/issues/46469).
            
        Here is a `compose.yaml` snippet that applies the inbound + outbound settings to the default bridge network Docker Compose creates (_if it already exists, you will need to ensure it's re-created to apply the updated settings_):
        
        ```yaml title="compose.yaml"
        networks:
          default:
            driver_opts:
              # Set a specific IP to default bind container ports to instead of `0.0.0.0`:
              # https://docs.docker.com/engine/network/drivers/bridge/#default-host-binding-address
              com.docker.network.bridge.host_binding_ipv4: 198.51.100.42
              # Force a specific source IP (SNAT):
              # https://github.com/moby/libnetwork/pull/2454
              com.docker.network.host_ipv4: 198.51.100.42
        ```

!!! note "IP addresses for documentation"

    IP addresses shown in above examples are placeholders, they are IP addresses reserved for documentation by IANA (_[RFC-5737 (IPv4)][rfc-5737] and [RFC-3849 (IPv6)][rfc-3849]_). Replace them with the IP addresses you want DMS to send mail through.
    
[rfc-5737]: https://datatracker.ietf.org/doc/html/rfc5737
[rfc-3849]: https://datatracker.ietf.org/doc/html/rfc3849

[gh-pr::3465::comment-restrictions]: https://github.com/docker-mailserver/docker-mailserver/pull/3465#discussion_r1458114528
[gh-pr::3465::alternative-solution]: https://github.com/docker-mailserver/docker-mailserver/pull/3465#issuecomment-1678107233
[gh-src::postfix-master-cf::relay-transport]: https://github.com/docker-mailserver/docker-mailserver/blob/9cdbef2b369fb4fb0f1b4e534da8703daf92abc9/target/postfix/master.cf#L65

