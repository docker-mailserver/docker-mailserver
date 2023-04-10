---
title: 'Advanced | IPv6'
---

!!! bug "Ample Opportunities for Issues"

    Numerous bug reports have been raised in the past about IPv6. Please make sure your setup around DMS is correct when using IPv6!

## Issues with Docker

### Background

If your host supports IPv6, then DMS can automatically accept IPv6 connections. The issue is with _Docker_'s [NAT64]:  incoming mails will fail SPF checks because they will appear to come from the IPv4 gateway ((most likely `172.20.0.1`)) that Docker is using to proxy the IPv6 connection.

To read on, issues [#1438][github-issue-1438] & [#3057][github-issue-3057] provide material for further discussion.

[wikipedia-nat64]: https://en.wikipedia.org/wiki/NAT64
[github-issue-1438]: https://github.com/docker-mailserver/docker-mailserver/issues/1438
[github-issue-3057]: https://github.com/docker-mailserver/docker-mailserver/pull/3057#issuecomment-1416706615

### Solution

The issue can be solved by supporting IPv6 connections all the way to the DMS container.

You definitely want to make sure Docker has IPv6 enabled. The [official Docker documentation on enabling IPv6][docker-docs-enable-ipv6] provides you information on how to do that. Thereafter, if you want to use container networking with IPv6, make sure you have the following in `/etc/docker/daemon.json`:

```json
{
  "ip6tables": true,
  "experimental" : true,
  "userland-proxy": true
}
```

You'll need to restart the daemon if it's running, not just reload it. The above enables the IPv6 NAT which will avoid the routing to IPv4, so long as the container is on an ipv6 network that we'll configure next. `experimental` is required currently for `ip6tables` to work; we think `userland-proxy` is too (_although this setting should be enabled by default, there is upstream talk to switch to disabled by default though_).

Then you need to configure a network for your container, in `docker-compose.yaml` the default bridge network isn't the same as the default bridge config in `/etc/docker/daemon.json`, that only applies to `docker` CLI (eg `docker run`). Instead you can [override the default network like I detailed here](https://github.com/nginx-proxy/nginx-proxy/issues/133#issuecomment-1368745843):

```yaml
networks:
  # Overrides the `default` compose generated network, avoids needing to attach to each service:
  default:
    enable_ipv6: true
    # An IPv4 subnet is implicitly configured, IPv6 needs to be specified:
    ipam:
      config:
        - subnet: fd00:cafe:babe::/48
```

[docker-docs-enable-ipv6]: https://docs.docker.com/config/daemon/ipv6/
