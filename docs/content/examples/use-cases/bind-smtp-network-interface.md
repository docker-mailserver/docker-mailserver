---
title: 'Use Cases | Binding outbound SMTP to a specific network'
hide:
  - toc
---

!!! warning "Advice not extensively tested"

    This configuration advice is a community contribution.

If your Docker host has multiple public IPv4 or IPv6 IP addresses, it may be beneficial to bind outgoing SMTP connections to a specific IP.

When the IP address for DMS is inconsistent, it may fail to pass common security checks when interacting with other mail servers:

- When a mail is sent outbound from DMS, it connects to the external MTA and greets it with an EHLO (the DMS FQDN) which the MTA might verify that the EHLO address resolves to the same IP that DMS is connecting to the MTA from, and that a `PTR` record for that same IP resolves back to that same IP (_the `PTR` record address may not need to match the DMS FQDN_).
- SPF is common requirement which verifies the SPF `TXT` DNS record for the _envelope sender address_ is valid when it references any DNS values (`MX`, `A`, `AAAA`).
- There may be other security checks handled by an MTA, like [Postfix supports with `reject_unknown_sender`][gh-pr::3465::comment-restrictions].

!!! note "IP addresses for documentation"

    IP addresses shown in the below examples (`198.51.100.42` + `2001:DB8::42`) are placeholders, they are IP addresses reserved for documentation by IANA (_[RFC-5737 (IPv4)][rfc-5737] and [RFC-3849 (IPv6)][rfc-3849]_). Replace them with the IP addresses you want DMS to send mail through.

## Directly binding

This approach is for when the DMS container uses a [`network_mode`][docker-docs::compose-config::network-mode] / [`networks`][docker-docs::compose-config::networks] where the host IP is available to bind internally, such as [host][docker-docs::network-driver::host] and [macvlan][docker-docs::network-driver::macvlan].

This can be configured by [overriding the default Postfix configurations][docs::overrides-postfix] DMS provides. Create `postfix-master.cf` and `postfix-main.cf` files for your config volume (`docker-data/dms/config`).

In `postfix-main.cf` you'll have to set the [`smtp_bind_address`][postfix-docs::smtp-bind-address-ipv4] and [`smtp_bind_address6`][postfix-docs::smtp-bind-address-ipv6] to the respective IP-address on the server you want to use.

!!! example

    === "Contributed solution"

        ```title="postfix-main.cf"
        smtp_bind_address = 198.51.100.42
        smtp_bind_address6 = 2001:DB8::42
        ```

        !!! bug "Inheriting the bind from `main.cf` can misconfigure services"

            One problem when setting `smtp_bind_address` in `main.cf` is that it will be inherited by any services in `master.cf` that extend the `smtp` transport.

            One of these is `smtp-amavis`, which is explicitly configured to listen / connect via loopback (`localhost` / `127.0.0.1`).

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

        If that avoids the concern with `smtp-amavis`, you may still need to additionally override for the [`relay` transport][gh-src::postfix-master-cf::relay-transport] as well if you have configured DMS to send mail through a relay service.
        
## Bridged Networks
    
When your DMS container is using a bridge network, you'll instead need to restrict which IP address inbound and outbound traffic is routed through via the bridged interface.

!!! info

    For **inbound** traffic, you may configure this at whatever scope is most appropriate for you:
    
    - **Daemon:** Change the [default bind address][inbound-ip::docker-docs::daemon] configured in `/etc/docker/daemon.json` (default `0.0.0.0`).
    - **Network:** Assign the [`host_binding_ipv4` bridge driver option][inbound-ip::docker-docs::network] as shown in the below `compose.yaml` snippet.
    - **Container:** Provide an explicit host IP address when [publishing a port][inbound-ip::docker-docs::container].
    
    For **outbound** traffic, the bridge network will use the default route. You can change this by either:
    
    - [Manually routing networks][outbound-ip::route-manually] on the host.
    - Use the [`host_ipv4` driver option][outbind-ip::host-ipv4] for Docker networks to force the SNAT (source IP) that the bridged network will route outbound traffic through.
        - This IP address must belong to a network interface to be routed through it.
        - IPv6 support via `host_ipv6` [requires at least Docker v25][outbind-ip::host-ipv6].

!!! example

    Here is a `compose.yaml` snippet that applies the inbound + outbound settings to the default bridge network Docker Compose creates (_if it already exists, you will need to ensure it's re-created to apply the updated settings_):
    
    ```yaml title="compose.yaml"
    networks:
      default:
        driver_opts:
          # Inbound IP (sets the host IP that published ports receive traffic from):
          com.docker.network.bridge.host_binding_ipv4: 198.51.100.42
          # Outbound IP (sets the host IP that external hosts will receive connections from):
          com.docker.network.host_ipv4: 198.51.100.42
    ```

[docker-docs::network-driver::host]: https://docs.docker.com/engine/network/drivers/host
[docker-docs::network-driver::macvlan]: https://docs.docker.com/engine/network/drivers/macvlan
[docker-docs::compose-config::network-mode]: https://docs.docker.com/reference/compose-file/services/#network_mode
[docker-docs::compose-config::networks]: https://docs.docker.com/reference/compose-file/services/#networks

[docs::overrides-postfix]: ../../config/advanced/override-defaults/postfix.md
[postfix-docs::smtp-bind-address-ipv4]: https://www.postfix.org/postconf.5.html#smtp_bind_address
[postfix-docs::smtp-bind-address-ipv6]: https://www.postfix.org/postconf.5.html#smtp_bind_address6

[rfc-5737]: https://datatracker.ietf.org/doc/html/rfc5737
[rfc-3849]: https://datatracker.ietf.org/doc/html/rfc3849

[gh-pr::3465::comment-restrictions]: https://github.com/docker-mailserver/docker-mailserver/pull/3465#discussion_r1458114528
[gh-pr::3465::alternative-solution]: https://github.com/docker-mailserver/docker-mailserver/pull/3465#issuecomment-1678107233
[gh-src::postfix-master-cf::relay-transport]: https://github.com/docker-mailserver/docker-mailserver/blob/9cdbef2b369fb4fb0f1b4e534da8703daf92abc9/target/postfix/master.cf#L65

[inbound-ip::docker-docs::daemon]: https://docs.docker.com/reference/cli/dockerd/#default-network-options
[inbound-ip::docker-docs::network]: https://docs.docker.com/engine/network/drivers/bridge/#default-host-binding-address
[inbound-ip::docker-docs::container]: https://docs.docker.com/reference/compose-file/services/#ports
[outbound-ip::route-manually]: https://github.com/moby/moby/issues/30053#issuecomment-1077041045
[outbind-ip::host-ipv4]: https://github.com/moby/libnetwork/pull/2454
[outbind-ip::host-ipv6]: https://github.com/moby/moby/issues/46469
