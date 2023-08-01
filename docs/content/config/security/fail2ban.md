---
title: 'Security | Fail2Ban'
hide:
  - toc # Hide Table of Contents for this page
---

!!! quote "What is Fail2Ban (F2B)?"

    Fail2ban is an intrusion prevention software framework. Written in the Python programming language, it is designed to prevent against brute-force attacks. It is able to run on POSIX systems that have an interface to a packet-control system or firewall installed locally, such as \[NFTables\] or TCP Wrapper.

    [Source][wikipedia-fail2ban]

    [wikipedia-fail2ban]: https://en.wikipedia.org/wiki/Fail2ban

## Configuration

!!! warning

    DMS must be launched with the `NET_ADMIN` capability in order to be able to install the NFTables rules that actually ban IP addresses. Thus, either include `--cap-add=NET_ADMIN` in the `docker run` command, or the equivalent in the `compose.yaml`:

    ```yaml
    cap_add:
      - NET_ADMIN
    ```

!!! bug "Running Fail2Ban on Older Kernels"

    DMS configures F2B to use NFTables, not IPTables (legacy). We have observed that older systems, for example NAS systems, do not support the modern NFTables rules. You will need to configure F2B to use legacy IPTables again, for example with the [``fail2ban-jail.cf``][github-file-f2bjail], see the [section on configuration further down below](#custom-files).

### DMS Defaults

DMS will automatically ban IP addresses of hosts that have generated 6 failed attempts over the course of the last week. The bans themselves last for one week. The Postfix jail is configured to use `mode = extra` in DMS.

### Custom Files

!!! question "What is [`docker-data/dms/config/`][docs-dms-config-volume]?"

This following configuration files inside the `docker-data/dms/config/` volume will be copied inside the container during startup

1. `fail2ban-jail.cf` is copied to `/etc/fail2ban/jail.d/user-jail.local`
    - with this file, you can adjust the configuration of individual jails and their defaults
    - there is an example provided [in our repository on GitHub][github-file-f2bjail]
2. `fail2ban-fail2ban.cf` is copied to `/etc/fail2ban/fail2ban.local`
    - with this file, you can adjust F2B behavior in general
    - there is an example provided [in our repository on GitHub][github-file-f2bconfig]

[docs-dms-config-volume]: ../../faq.md#what-about-the-docker-datadmsconfig-directory
[github-file-f2bjail]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config-examples/fail2ban-jail.cf
[github-file-f2bconfig]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config-examples/fail2ban-fail2ban.cf

### Viewing All Bans

When just running

```bash
setup fail2ban
```

the script will show all banned IP addresses.

To get a more detailed `status` view, run

```bash
setup fail2ban status
```

### Managing Bans

You can manage F2B with the `setup` script. The usage looks like this:

```bash
docker exec <CONTAINER NAME> setup fail2ban [<ban|unban> <IP>]
```

### Viewing the Log File

```bash
docker exec <CONTAINER NAME> setup fail2ban log
```

## Running Inside A Rootless Container

[`RootlessKit`][rootless::rootless-kit] is the _fakeroot_ implementation for supporting _rootless mode_ in Docker and Podman. By default, RootlessKit uses the [`builtin` port forwarding driver][rootless::port-drivers], which does not propagate source IP addresses.

It is necessary for F2B to have access to the real source IP addresses in order to correctly identify clients. This is achieved by changing the port forwarding driver to [`slirp4netns`][rootless::slirp4netns], which is slower than the builtin driver but does preserve the real source IPs.

[rootless::rootless-kit]: https://github.com/rootless-containers/rootlesskit
[rootless::port-drivers]: https://github.com/rootless-containers/rootlesskit/blob/v0.14.5/docs/port.md#port-drivers
[rootless::slirp4netns]: https://github.com/rootless-containers/slirp4netns

=== "Docker"

    For [rootless mode][rootless::docker] in Docker, create `~/.config/systemd/user/docker.service.d/override.conf` with the following content:

    !!! danger inline end

        This changes the port driver for all rootless containers managed by Docker. Per container configuration is not supported, if you need that consider Podman instead.

    ```cf
    [Service]
    Environment="DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER=slirp4netns"
    ```

    And then restart the daemon:

    ```console
    $ systemctl --user daemon-reload
    $ systemctl --user restart docker
    ```

    [rootless::docker]: https://docs.docker.com/engine/security/rootless

=== "Podman"

    [Rootless Podman][rootless::podman] requires adding the value `slirp4netns:port_handler=slirp4netns` to the `--network` CLI option, or `network_mode` setting in your `compose.yaml`:

    !!! example

        ```yaml
        services:
          mailserver:
            network_mode: "slirp4netns:port_handler=slirp4netns"
            environment:
              - ENABLE_FAIL2BAN=1
              - NETWORK_INTERFACE=tap0
              ...
        ```

    You must also add the ENV `NETWORK_INTERFACE=tap0`, because Podman uses a [hard-coded interface name][rootless::podman::interface] for `slirp4netns`. `slirp4netns` is not compatible with user-defined networks!

    [rootless::podman]: https://github.com/containers/podman/blob/v3.4.1/docs/source/markdown/podman-run.1.md#--networkmode---net
    [rootless::podman::interface]: https://github.com/containers/podman/blob/v3.4.1/libpod/networking_slirp4netns.go#L264
