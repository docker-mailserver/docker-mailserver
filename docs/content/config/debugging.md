---
title: 'Debugging'
hide:
    - toc
---

This page contains valuable information when it comes to resolving issues you encounter.

!!! info "Contributions Welcome!"

    Please consider contributing solutions to the [FAQ][docs-faq] :heart:

## Preliminary Checks

- Check that all published DMS ports are actually open and not blocked by your ISP / hosting provider.
- SSL errors are likely the result of a wrong setup on the user side and not caused by DMS itself.

### Mail sent from DMS does not arrive at destination

Some service providers block outbound traffic on port 25. Common hosting providers known to have this issue:

- [Azure](https://docs.microsoft.com/en-us/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)
- [AWS EC2](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/)
- [Vultr](https://www.vultr.com/docs/what-ports-are-blocked/)

These links may advise how the provider can unblock the port through additional services offered, or via a support ticket request.

## Steps for Debugging DMS

1. **Increase log verbosity**: Very helpful for troubleshooting problems during container startup. Set the environment variable [`LOG_LEVEL`][docs-environment-log-level] to `debug` or `trace`.
2. **Use error logs as a search query**: Try [finding an _existing issue_][gh-issues] or _search engine result_ from any errors in your container log output. Often you'll find answers or more insights. If you still need to open an issue, sharing links from your search may help us assist you. The mail server log can be acquired by running `docker log <CONTAINER NAME>` (_or `docker logs -f <CONTAINER NAME>` if you want to follow the log_).
3. **Understand the basics of mail servers**: Especially for beginners, make sure you read our [Introduction][docs-introduction] and [Usage][docs-usage] articles.
4. **Search the whole FAQ**: Our [FAQ][docs-faq] contains answers for common problems. Make sure you go through the list.
5. **Reduce the scope**: Ensure that you can run a basic setup of DMS first. Then incrementally restore parts of your original configuration until the problem is reproduced again. If you're new to DMS, it is common to find the cause is misunderstanding how to configure a minimal setup.

### Debug a running container

To get a shell inside the container run: `docker exec -it <CONTAINER NAME> bash`.

If you need more flexibility than `docker logs` offers, within the container `/var/log/mail/mail.log` and `/var/log/supervisor/` are the most useful locations to get relevant DMS logs. Use the `tail` or `cat` commands to view their contents.

To install additional software:

1. `apt-get update` to update repository metadata.
2. `apt-get install <PACKAGE>`

For example a text editor you can use in the terminal: `apt-get install nano`

## Compatibility

It's possible that the issue you're experiencing is due to a compatibility conflict.

This could be from outdated software, or running a system that isn't able to provide you newer software and kernels. You may want to verify if you can reproduce the issue on a system that is not affected by these concerns.

### Network

- Misconfigured network connections can cause the client IP address to be proxied through a docker network gateway IP, or a [service that acts on behalf of connecting clients for logins][gh-discuss-roundcube-fail2ban] where the connections client IP appears to be only from that service (eg: Container IP) instead. This can relay the wrong information to other services (eg: monitoring like Fail2Ban, SPF verification) causing unexpected failures.
- **`userland-proxy`:** Prior to Docker `v23`, [changing the `userland-proxy` setting did not reliably remove NAT rules][network::docker-userlandproxy].
- **UFW / firewalld:** Some users expect only their firewall frontend to manage the firewall rules, but these will be bypassed when Docker publishes a container port (_as there is no integration between the two_).
- **`iptables` / `nftables`:**
    - Docker [only manages the NAT rules via `iptables`][network::docker-nftables], relying on compatibility shims for supporting the successor `nftables`. Internally DMS expects `nftables` support on the host kernel for services like Fail2Ban to function correctly.
    - [Kernels older than 5.2 may affect management of NAT rules via `nftables`][network::kernel-nftables]. Other software outside of DMS may also manipulate these rules, such as firewall frontends.
- **IPv6:**
    - Requires [additional configuration][docs-ipv6] to prevent or properly support IPv6 connections (eg: Preserving the Client IP).
    - Support in 2023 is still considered experimental. You are advised to use at least Docker Engine `v23` (2023Q1).
    - Various networking bug fixes have been addressed since the initial IPv6 support arrived in Docker Engine `v20.10.0` (2020Q4).

### System

- **Kernel:** Some systems provide [kernels with modifications (_replacing defaults and backporting patches_)][network::kernels-modified] to support running legacy software or kernels, complicating compatibility. This can be commonly experienced with products like NAS.
- **CGroups v2:** Hosts running older kernels (prior to 5.2) and systemd (prior to v244) are not likely to leverage cgroup v2, or have not defaulted to the cgroup v2 `unified` hierarchy. Not meeting this baseline may influence the behaviour of your DMS container, even with the latest Docker Engine installed.
- **Container runtime:** Docker and Podman for example have subtle differences. DMS docs are primarily focused on Docker, but we try to document known issues where relevant.
- **Rootless containers:** Introduces additional differences in behaviour or requirements:
    - cgroup v2 is required for supporting rootless containers.
    - Differences such as for container networking which may further affect support for IPv6 and preserving the client IP (Remote address). Example with Docker rootless are [binding a port to a specific interface][docker-rootless-interface] and the choice of [port forwarding driver][docs-rootless-portdriver].

[network::docker-userlandproxy]: https://github.com/moby/moby/issues/44721
[network::docker-nftables]: https://github.com/moby/moby/issues/26824
[network::kernels-modified]: https://github.com/docker-mailserver/docker-mailserver/pull/2662#issuecomment-1168435970
[network::kernel-nftables]: https://unix.stackexchange.com/questions/596493/can-nftables-and-iptables-ip6tables-rules-be-applied-at-the-same-time-if-so-wh/596497#596497

[docs-faq]: ../faq.md
[docs-environment-log-level]: ./environment.md#log_level
[docs-ipv6]: ./advanced/ipv6.md
[docs-introduction]: ../introduction.md
[docs-usage]: ../usage.md
[gh-issues]: https://github.com/docker-mailserver/docker-mailserver/issues
[gh-discuss-roundcube-fail2ban]: https://github.com/orgs/docker-mailserver/discussions/3273#discussioncomment-5654603

[docker-rootless-interface]: https://github.com/moby/moby/issues/45742
[docs-rootless-portdriver]: ./security/fail2ban.md#running-inside-a-rootless-container
