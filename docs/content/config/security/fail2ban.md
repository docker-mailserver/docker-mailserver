---
title: 'Security | Fail2Ban'
hide:
  - toc # Hide Table of Contents for this page
---

Fail2Ban is installed automatically and bans IP addresses for 3 hours after 3 failed attempts in 10 minutes by default.

## Configuration files

If you want to change this, you can easily edit our github example file: [`config/fail2ban-jail.cf`][github-file-f2bjail].

You can do the same with the values from `fail2ban.conf`, e.g `dbpurgeage`. In that case you need to edit: [`config/fail2ban-fail2ban.cf`][github-file-f2bconfig].

The configuration files need to be located at the root of the `/tmp/docker-mailserver/` volume bind (usually `./docker-data/dms/config/:/tmp/docker-mailserver/`).

This following configuration files from `/tmp/docker-mailserver/` will be copied during container startup.

- `fail2ban-jail.cf` -> `/etc/fail2ban/jail.d/user-jail.local`
- `fail2ban-fail2ban.cf` -> `/etc/fail2ban/fail2ban.local`

### Docker-compose config

Example configuration volume bind:

```yaml
    volumes:
      - ./docker-data/dms/config/:/tmp/docker-mailserver/
```

!!! attention
    `docker-mailserver` must be launched with the `NET_ADMIN` capability in order to be able to install the iptable rules that actually ban IP addresses.

    Thus either include `--cap-add=NET_ADMIN` in the `docker run` command, or the equivalent in `docker-compose.yml`:

    ```yaml
    cap_add:
      - NET_ADMIN
    ```

If you don't you will see errors the form of:

```log
iptables -w -X f2b-postfix -- stderr: "getsockopt failed strangely: Operation not permitted\niptables v1.4.21: can't initialize iptabl
es table `filter': Permission denied (you must be root)\nPerhaps iptables or your kernel needs to be upgraded.\niptables v1.4.21: can'
t initialize iptables table `filter': Permission denied (you must be root)\nPerhaps iptables or your kernel needs to be upgraded.\n"
2016-06-01 00:53:51,284 fail2ban.action         [678]: ERROR   iptables -w -D INPUT -p tcp -m multiport --dports smtp,465,submission -
j f2b-postfix
```

## Running fail2ban in a rootless container

[`RootlessKit`](https://github.com/rootless-containers/rootlesskit), the default fakeroot engine for a rootless mode in Docker and Podman, by default uses a [built-in port forwarding driver](https://github.com/rootless-containers/rootlesskit/blob/v0.14.5/docs/port.md#port-drivers), which does not preserve source IP addresses.

It is necessary for `fail2ban` to have access to correct source IP addresses in order to correctly identify clients. So you have to switch port forwarding backend to [`slirp4netns's`](https://github.com/rootless-containers/slirp4netns) implementation, which is slower than `RootlessKit's` one, but does preserve source IPs.

### Switching to `slirp4netns` port handler in Docker

While running Docker in the [rootless mode](https://docs.docker.com/engine/security/rootless), create `~/.config/systemd/user/docker.service.d/override.conf` with the following content:

```
[Service]
Environment="DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER=slirp4netns"
```

And then restart the daemon:

```console
$ systemctl --user daemon-reload
$ systemctl --user restart docker
```

### Switching to `slirp4netns` port handler in Podman

In contrast to Docker, which changes have to be global for all user's containers, Podman [can achieve this](https://github.com/containers/podman/blob/v3.4.1/docs/source/markdown/podman-run.1.md#--networkmode---net) by running a specific container with the `--network slirp4netns:port_handler=slirp4netns` option, or passing it via `docker-compose` configuration:

```yaml
services:
  mailserver:
    network_mode: "slirp4netns:port_handler=slirp4netns"
```

You also have to change `NETWORK_INTERFACE` environment variable to `tap0` because Podman uses a [hardcoded interface name](https://github.com/containers/podman/blob/v3.4.1/libpod/networking_slirp4netns.go#L264) for `slirp4netns` configuration:

```yaml
services:
  mailserver:
    environment:
      - ENABLE_FAIL2BAN=1
      - NETWORK_INTERFACE=tap0
      ...
```

## Manage bans

You can also manage and list the banned IPs with the [`setup.sh`][docs-setupsh] script.

### List bans

```sh
./setup.sh debug fail2ban
```

### Un-ban

Here `192.168.1.15` is our banned IP.

```sh
./setup.sh debug fail2ban unban 192.168.1.15
```

[docs-setupsh]: ../setup.sh.md
[github-file-f2bjail]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config/fail2ban-jail.cf
[github-file-f2bconfig]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config/fail2ban-fail2ban.cf
