---
title: 'Advanced | IPv6'
---

!!! bug "Ample Opportunities for Issues"

    Numerous bug reports have been raised in the past about IPv6. Please make sure your setup around DMS is correct when using IPv6!

## IPv6 networking problems with Docker defaults

If your host system supports IPv6 and an `AAAA` DNS record exists to direct IPv6 traffic to DMS, you may experience compatibility issues.

Docker containers typically use a bridge network with [NAT64][wikipedia-nat64]. When the host receives a connection on the IPv6 interface, it is routed to the containers bridge network managed by Docker. By default, the Docker daemon only assigns IPv4 addresses to containers, thus at this stage the IPv6 context of the original client connection is lost.

Internally, the container is no longer aware of the original client IPv6 address, it has been proxied through the IPv4 gateway address of it's connected network (_eg: `172.17.0.1`, Docker allocates networks from a set of [default subnets][docker-subnets]_).

The impact of losing the real IP of the client connection can negatively affect DMS:

- Users unable to login (_Fail2Ban action triggered by repeated failures using the same internal Gateway IP_)
- Rejecting inbound mail (_[SPF verification failure][gh-issue-1438-spf], IP mismatch_)
- Delivery failures from [sender reputation][sender-score] being reduced (_due to [bouncing inbound mail][gh-issue-3057-bounce] from rejected IPv6 clients_)

## Proper IPv6 configuration

You can enable IPv6 support in Docker for container networks, however [compatibility concerns][docs-compat] may affect your success.

The [official Docker documentation on enabling IPv6][docker-docs-enable-ipv6] has been improving and is a good resource to reference.

Enable `ip6tables` so that Docker will manage IPv6 networking rules as well. This will allow for IPv6 NAT to work like IPv4 does for your containers, avoiding the above issue with external connections having their IP address seen as the containers network gateway IP.

!!! example "Configure the following in `/etc/docker/daemon.json`"

    ```json
    {
      "ip6tables": true,
      "experimental" : true,
      "userland-proxy": true
    }
    ```

    - `experimental: true` is currently required for `ip6tables: true` to work.
    - `userland-proxy: true` may provide better compatibility (_presently default in Docker_).

    Now restart the daemon if it's running: `systemctl restart docker`.

Next, configure a network for your container with any of these:

- [User-defined networks via `docker network create` or `compose.yaml`][docker-docs-ipv6-create-custom]
- [Default docker bridge][docker-docs-ipv6-create-default] (_docker CLI only, not helpful for `compose.yaml`_)
- [Default network for a `compose.yaml`][ipv6-config-example] (_ `/etc/docker/daemon.json` settings for default bridge do not apply, instead override the generated `default` network_)

!!! danger "Do not use `2001:db8:1::/64` for your private subnet"

    The `2001:db8` address prefix is [reserved for documentation][wikipedia-ipv6-reserved]. Avoid using a subnet with this prefix.

### Configuring an IPv6 subnet

If you've [configured IPv6 address pools in `/etc/docker/daemon.json`][docker-docs-ipv6-supernets], you do not need to specify a subnet explicitly. Otherwise if you're unsure what value to provide, here's a quick guide (_Tip: Prefer IPv6 ULA, it's the least hassle_):

- `fd00:cafe:face:feed::/64` is an example of a [IPv6 ULA subnet][wikipedia-ipv6-ula]. ULA addresses are akin to the [private IPv4 subnets][wikipedia-ipv4-private] you may already be familiar with. You can use that example, or choose your own ULA address. This is a good choice for getting Docker containers to their have networks support IPv6 via NAT like they already do by default with IPv4.
- IPv6 without NAT, using public address space like your server is assigned belongs to an [IPv6 GUA subnet][wikipedia-ipv6-gua].
    - Typically these will be a `/64` block assigned to your host, but this varies by provider.
    - These addresses do not need to publish ports of a container to another IP to be publicly reached, you will want a firewall configured to manage which ports are accessible instead as no NAT is involved. Note that this may not be desired if the container should also be reachable via the host IPv4 public address.
    - You may want to subdivide the `/64` into smaller subnets for Docker to use only portions of the `/64`. This can reduce some routing features, and [require additional setup / management via a NDP Proxy][gh-pull-3244-gua] for your public interface to know of IPv6 assignments managed by Docker and accept external traffic.

!!! info "IPv6 ULA addresses priority"

    IPv6 ULA have lower priority than IPv4 private addresses when a DNS lookup could return either IP (eg: `localhost`).

    This shouldn't cause any issues, but the behaviour differs from other IPv6 addresses priority and should only be relevant to internal networking.

[wikipedia-nat64]: https://en.wikipedia.org/wiki/NAT64
[docker-subnets]: https://straz.to/2021-09-08-docker-address-pools/#what-are-the-default-address-pools-when-no-configuration-is-given-vanilla-pools
[sender-score]: https://senderscore.org/assess/get-your-score/
[gh-issue-1438-spf]: https://github.com/docker-mailserver/docker-mailserver/issues/1438
[gh-issue-3057-bounce]: https://github.com/docker-mailserver/docker-mailserver/pull/3057#issuecomment-1416700046

[docs-compat]: ../debugging.md#compatibility

[docker-docs-enable-ipv6]: https://docs.docker.com/config/daemon/ipv6/
[docker-docs-ipv6-create-custom]: https://docs.docker.com/config/daemon/ipv6/#create-an-ipv6-network
[docker-docs-ipv6-create-default]: https://docs.docker.com/config/daemon/ipv6/#use-ipv6-for-the-default-bridge-network
[docker-docs-ipv6-supernets]: https://docs.docker.com/config/daemon/ipv6/#dynamic-ipv6-subnet-allocation

[ipv6-config-example]: https://github.com/nginx-proxy/nginx-proxy/issues/133#issuecomment-1368745843
[wikipedia-ipv6-reserved]: https://en.wikipedia.org/wiki/IPv6_address#Documentation
[wikipedia-ipv4-private]: https://en.wikipedia.org/wiki/Private_network#Private_IPv4_addresses
[wikipedia-ipv6-ula]: https://en.wikipedia.org/wiki/Unique_local_address
[wikipedia-ipv6-gua]: https://en.wikipedia.org/wiki/IPv6#Global_addressing

[gh-pull-3244-gua]: https://github.com/docker-mailserver/docker-mailserver/pull/3244#issuecomment-1528984894
