---
title: 'Advanced | IPv6'
---

!!! bug "Ample Opportunities for Issues"

    Numerous bug reports have been raised in the past about IPv6. Please make sure your setup around DMS is correct when using IPv6!

## IPv6 networking problems with Docker defaults

### What can go wrong?

If your host system supports IPv6 and an `AAAA` DNS record exists to direct IPv6 traffic to DMS, you may experience issues when an IPv6 connection is made:

- The original client IP is replaced with the gateway IP of a docker network.
- Connections fail or hang.

The impact of losing the real IP of the client connection can negatively affect DMS:

- Users unable to login (_Fail2Ban action triggered by repeated login failures all seen as from the same internal Gateway IP_)
- Mail inbound to DMS is rejected (_[SPF verification failure][gh-issue-1438-spf], IP mismatch_)
- Delivery failures from [sender reputation][sender-score] being reduced (_due to [bouncing inbound mail][gh-issue-3057-bounce] from rejected IPv6 clients_)
- Some services may be configured to trust connecting clients within the containers subnet, which includes the Gateway IP. This can risk bypassing or relaxing security measures, such as exposing an [open relay][wikipedia-openrelay].

### Why does this happen?

When the host network receives a connection to a containers published port, it is routed to the containers internal network managed by Docker (_typically a bridge network_).

By default, the Docker daemon only assigns IPv4 addresses to containers, thus it will only accept IPv4 connections (_unless a `docker-proxy` process is listening, which the default daemon setting `userland-proxy: true` enables_). With the daemon setting `userland-proxy: true` (default), IPv6 connections from the host can also be accepted and routed to containers (_even when they only have IPv4 addresses assigned_). `userland-proxy: false` will require the container to have atleast an IPv6 address assigned.

This can be problematic for IPv6 host connections when internally the container is no longer aware of the original client IPv6 address, as it has been proxied through the IPv4 or IPv6 gateway address of it's connected network (_eg: `172.17.0.1` - Docker allocates networks from a set of [default subnets][docker-subnets]_).

This can be fixed by enabling a Docker network to assign IPv6 addresses to containers, along with some additional configuration. Alternatively you could configure the opposite to prevent IPv6 connections being made.

## Prevent IPv6 connections

- Avoiding an `AAAA` DNS record for your DMS FQDN would prevent resolving an IPv6 address to connect to.
- You can also use `userland-proxy: false`, which will fail to establish a remote connection to DMS (_provided no IPv6 address was assigned_).

!!! tip "With UFW or Firewalld"

    When one of these firewall frontends are active, remote clients should fail to connect instead of being masqueraded as the docker network gateway IP. Keep in mind that this only affects remote clients, it does not affect local IPv6 connections originating within the same host.

## Enable proper IPv6 support

You can enable IPv6 support in Docker for container networks, however [compatibility concerns][docs-compat] may affect your success.

The [official Docker documentation on enabling IPv6][docker-docs-enable-ipv6] has been improving and is a good resource to reference.

Enable `ip6tables` support so that Docker will manage IPv6 networking rules as well. This will allow for IPv6 NAT to work like the existing IPv4 NAT already does for your containers, avoiding the above issue with external connections having their IP address seen as the container network gateway IP (_provided an IPv6 address is also assigned to the container_).

!!! example "Configure the following in `/etc/docker/daemon.json`"

    ```json
    {
      "ip6tables": true,
      "experimental" : true,
      "userland-proxy": true
    }
    ```

    - `experimental: true` is currently required for `ip6tables: true` to work.
    - `userland-proxy` setting [can potentially affect connection behaviour][gh-pull-3244-proxy] for local connections.

    Now restart the daemon if it's running: `systemctl restart docker`.

Next, configure a network for your container with any of these:

- [User-defined networks via `docker network create` or `compose.yaml`][docker-docs-ipv6-create-custom]
- [Default docker bridge][docker-docs-ipv6-create-default] (_docker CLI only, not helpful for `compose.yaml`_)
- [Default network for a `compose.yaml`][ipv6-config-example] (_`/etc/docker/daemon.json` settings for default bridge do not apply, instead override the generated `default` network_)

!!! danger "Do not use `2001:db8:1::/64` for your private subnet"

    The `2001:db8` address prefix is [reserved for documentation][wikipedia-ipv6-reserved]. Avoid using a subnet with this prefix.

!!! example "User-defined IPv6 ULA subnet"

    - Either of these should work well. You can use a smaller subnet size like `/112` if you prefer.
    - The network will also include an IPv4 subnet assigned implicitly.

    ```bash
    # CLI
    docker network create --ipv6 --subnet fd00:cafe:face:feed::/64 dms-ipv6
    ```

    ```yaml
    # compose.yaml
    networks:
      # Overrides the `default` compose generated network, avoids needing to attach to each service:
      default:
        enable_ipv6: true
        subnet: fd00:cafe:face:feed::/64
    ```

### Configuring an IPv6 subnet

If you've [configured IPv6 address pools in `/etc/docker/daemon.json`][docker-docs-ipv6-supernets], you do not need to specify a subnet explicitly. Otherwise if you're unsure what value to provide, here's a quick guide (_Tip: Prefer IPv6 ULA, it's the least hassle_):

- `fd00:cafe:face:feed::/64` is an example of a [IPv6 ULA subnet][wikipedia-ipv6-ula]. ULA addresses are akin to the [private IPv4 subnets][wikipedia-ipv4-private] you may already be familiar with. You can use that example, or choose your own ULA address. This is a good choice for getting Docker containers to their have networks support IPv6 via NAT like they already do by default with IPv4.
- IPv6 without NAT, using public address space like your server is assigned belongs to an [IPv6 GUA subnet][wikipedia-ipv6-gua].
    - Typically these will be a `/64` block assigned to your host, but this varies by provider.
    - These addresses do not need to publish ports of a container to another IP to be publicly reached (_thus `ip6tables: true` is not required_), you will want a firewall configured to manage which ports are accessible instead as no NAT is involved. Note that this may not be desired if the container should also be reachable via the host IPv4 public address.
    - You may want to subdivide the `/64` into smaller subnets for Docker to use only portions of the `/64`. This can reduce some routing features, and [require additional setup / management via a NDP Proxy][gh-pull-3244-gua] for your public interface to know of IPv6 assignments managed by Docker and accept external traffic.

### Verify remote IP is correct

With Docker CLI or Docker Compose, run a `traefik/whoami` container with your IPv6 docker network and port 80 published. You can then send a curl request (or via address in the browser) from another host (as your remote client) with an IPv6 network, the `RemoteAddr` value returned should match your client IPv6 address.

```bash
docker run --rm -d --network dms-ipv6 -p 80:80 traefik/whoami
# On a different host, replace `2001:db8::1` with your DMS host IPv6 address
curl --max-time 5 http://[2001:db8::1]:80
```

!!! info "IPv6 ULA address priority"

    DNS lookups that have records for both IPv4 and IPv6 addresses (_eg: `localhost`_) may prefer IPv4 over IPv6 (ULA) for private addresses, whereas for public addresses IPv6 has priority. This shouldn't be anything to worry about, but can come across as a surprise when testing your IPv6 setup on the same host instead of from a remote client.
    
    The preference can be controlled with [`/etc/gai.conf`][networking-gai], and appears was configured this way based on [the assumption that IPv6 ULA would never be used with NAT][networking-gai-blog]. It should only affect the destination resolved for outgoing connections, which for IPv6 ULA should only really affect connections between your containers / host. In future [IPv6 ULA may also be prioritized][networking-gai-rfc].

[docker-subnets]: https://straz.to/2021-09-08-docker-address-pools/#what-are-the-default-address-pools-when-no-configuration-is-given-vanilla-pools
[sender-score]: https://senderscore.org/assess/get-your-score/
[gh-issue-1438-spf]: https://github.com/docker-mailserver/docker-mailserver/issues/1438
[gh-issue-3057-bounce]: https://github.com/docker-mailserver/docker-mailserver/pull/3057#issuecomment-1416700046
[wikipedia-openrelay]: https://en.wikipedia.org/wiki/Open_mail_relay

[docs-compat]: ../debugging.md#compatibility

[gh-pull-3244-proxy]: https://github.com/docker-mailserver/docker-mailserver/pull/3244#issuecomment-1603436809
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

[networking-gai]: https://linux.die.net/man/5/gai.conf
[networking-gai-blog]: https://thomas-leister.de/en/lxd-prefer-ipv6-outgoing/
[networking-gai-rfc]:https://datatracker.ietf.org/doc/html/draft-ietf-v6ops-ula
