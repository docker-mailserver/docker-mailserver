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
- Ensure that you have correctly started DMS. Many problems related to configuration are due to this.

!!! danger "Correctly starting DMS"

    Use the [`--force-recreate`][docker-docs::force-recreate] option to avoid configuration mishaps: `docker compose up --force-recreate`

    Alternatively, always use `docker compose down` to stop DMS. **Do not** rely on `CTRL + C`, `docker compose stop`, or `docker compose restart`.

    ---

    DMS setup scripts are run when a container starts, but may fail to work properly if you do the following:

    - Stopping a container with commands like: `docker stop` or `docker compose up` stopped via `CTRL + C` instead of `docker compose down`.
    - Restarting a container.

    Volumes persist data across container instances, however the same container instance will keep internal changes not stored in a volume until the container is removed.

    Due to this, DMS setup scripts may modify configuration it has already modified in the past.

    - This is brittle as some changes are naive by assuming they are applied to the original configs from the image.
    - Volumes in `compose.yaml` are expected to persist any important data. Thus it should be safe to throwaway the container created each time, avoiding this config problem.

### Mail sent from DMS does not arrive at destination

Some service providers block outbound traffic on port 25. Common hosting providers known to have this issue:

- [Azure](https://docs.microsoft.com/en-us/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)
- [AWS EC2](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/)
- [Vultr](https://www.vultr.com/docs/what-ports-are-blocked/)

These links may advise how the provider can unblock the port through additional services offered, or via a support ticket request.

### Mail sent to DMS does not get delivered to user

Common logs related to this are:

- `warning: do not list domain domain.fr in BOTH mydestination and virtual_mailbox_domains`
- `Recipient address rejected: User unknown in local recipient table`

If your logs look like this, you likely have [assigned the same FQDN to the DMS `hostname` and your mail accounts][gh-issues::dms-fqdn-misconfigured] which is not supported by default. You can either adjust your DMS `hostname` or follow [this FAQ advice][docs::faq-bare-domain]

It is also possible that [DMS services are temporarily unavailable][gh-issues::dms-services-unavailable] when configuration changes are detected, producing the 2nd error. Certificate updates may be a less obvious trigger.

## Steps for Debugging DMS

1. **Increase log verbosity**: Very helpful for troubleshooting problems during container startup. Set the environment variable [`LOG_LEVEL`][docs-environment-log-level] to `debug` or `trace`.
2. **Use error logs as a search query**: Try [finding an _existing issue_][gh-issues] or _search engine result_ from any errors in your container log output. Often you'll find answers or more insights. If you still need to open an issue, sharing links from your search may help us assist you. The mail server log can be acquired by running `docker log <CONTAINER NAME>` (_or `docker logs -f <CONTAINER NAME>` if you want to follow the log_).
3. **Inspect the logs of the service that is failing**: We provide a dedicated paragraph on this topic [further down below](#logs).
4. **Understand the basics of mail servers**: Especially for beginners, make sure you read our [Introduction][docs-introduction] and [Usage][docs-usage] articles.
5. **Search the whole FAQ**: Our [FAQ][docs-faq] contains answers for common problems. Make sure you go through the list.
6. **Reduce the scope**: Ensure that you can run a basic setup of DMS first. Then incrementally restore parts of your original configuration until the problem is reproduced again. If you're new to DMS, it is common to find the cause is misunderstanding how to configure a minimal setup.

### Debug a running container

#### General

To get a shell inside the container run: `docker exec -it <CONTAINER NAME> bash`. To install additional software, run:

1. `apt-get update` to update repository metadata.
2. `apt-get install <PACKAGE>` to install a package, e.g., `apt-get install neovim` if you want to use NeoVim instead of `nano` (which is shipped by default).

#### Logs

If you need more flexibility than what the `docker logs` command offers, then the most useful locations to get relevant DMS logs within the container are:

- `/var/log/mail/<SERVICE>.log`
- `/var/log/supervisor/<SERVICE>.log`

You may use `nano` (a text editor) to edit files, while `less` (a file viewer) and `tail`/`cat` are useful tools to inspect the contents of logs.

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

- **macOS:** DMS has limited support for macOS. Often an issue encountered is due to permissions related to the `volumes` config in `compose.yaml`. You may have luck [trying `gRPC FUSE`][gh-macos-support] as the file sharing implementation; [`VirtioFS` is the successor][docker-macos-virtiofs] but presently appears incompatible with DMS.
- **Kernel:** Some systems provide [kernels with modifications (_replacing defaults and backporting patches_)][network::kernels-modified] to support running legacy software or kernels, complicating compatibility. This can be commonly experienced with products like NAS.
- **CGroups v2:** Hosts running older kernels (prior to 5.2) and systemd (prior to v244) are not likely to leverage cgroup v2, or have not defaulted to the cgroup v2 `unified` hierarchy. Not meeting this baseline may influence the behavior of your DMS container, even with the latest Docker Engine installed.
- **Container runtime:** Docker and Podman for example have subtle differences. DMS docs are primarily focused on Docker, but we try to document known issues where relevant.
- **Rootless containers:** Introduces additional differences in behavior or requirements:
    - cgroup v2 is required for supporting rootless containers.
    - Differences such as for container networking which may further affect support for IPv6 and preserving the client IP (Remote address). Example with Docker rootless are [binding a port to a specific interface][docker-rootless-interface] and the choice of [port forwarding driver][docs::fail2ban::rootless-portdriver].

[network::docker-userlandproxy]: https://github.com/moby/moby/issues/44721
[network::docker-nftables]: https://github.com/moby/moby/issues/26824
[network::kernels-modified]: https://github.com/docker-mailserver/docker-mailserver/pull/2662#issuecomment-1168435970
[network::kernel-nftables]: https://unix.stackexchange.com/questions/596493/can-nftables-and-iptables-ip6tables-rules-be-applied-at-the-same-time-if-so-wh/596497#596497

[docs-environment-log-level]: ./environment.md#log_level
[docs-faq]: ../faq.md
[docs::faq-bare-domain]: ../faq.md#can-i-use-a-nakedbare-domain-ie-no-hostname
[docs-ipv6]: ./advanced/ipv6.md
[docs-introduction]: ../introduction.md
[docs::fail2ban::rootless-portdriver]: ./security/fail2ban.md#rootless-container
[docs-usage]: ../usage.md

[gh-issues]: https://github.com/docker-mailserver/docker-mailserver/issues
[gh-issues::dms-fqdn-misconfigured]: https://github.com/docker-mailserver/docker-mailserver/issues/3679#issuecomment-1837609043
[gh-issues::dms-services-unavailable]: https://github.com/docker-mailserver/docker-mailserver/issues/3679#issuecomment-1848083358
[gh-macos-support]: https://github.com/docker-mailserver/docker-mailserver/issues/3648#issuecomment-1822774080
[gh-discuss-roundcube-fail2ban]: https://github.com/orgs/docker-mailserver/discussions/3273#discussioncomment-5654603

[docker-rootless-interface]: https://github.com/moby/moby/issues/45742
[docker-macos-virtiofs]: https://www.docker.com/blog/speed-boost-achievement-unlocked-on-docker-desktop-4-6-for-mac/
[docker-docs::force-recreate]: https://docs.docker.com/compose/reference/up/
