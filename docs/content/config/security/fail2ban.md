---
title: 'Security | Fail2Ban'
hide:
  - toc # Hide Table of Contents for this page
---

Fail2Ban is installed automatically and bans IP addresses for 3 hours after 3 failed attempts in 10 minutes by default.

## Configuration files

If you want to change this, you can easily edit our github example file: [`config-examples/fail2ban-jail.cf`][github-file-f2bjail].

You can do the same with the values from `fail2ban.conf`, e.g `dbpurgeage`. In that case you need to edit: [`config-examples/fail2ban-fail2ban.cf`][github-file-f2bconfig].

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
    `docker-mailserver` must be launched with the `NET_ADMIN` capability in order to be able to install the nftables rules that actually ban IP addresses.

    Thus either include `--cap-add=NET_ADMIN` in the `docker run` command, or the equivalent in `docker-compose.yml`:

    ```yaml
    cap_add:
      - NET_ADMIN
    ```

## Running fail2ban in a rootless container

[`RootlessKit`][rootless::rootless-kit] is the _fakeroot_ implementation for supporting _rootless mode_ in Docker and Podman. By default RootlessKit uses the [`builtin` port forwarding driver][rootless::port-drivers], which does not propagate source IP addresses.

It is necessary for `fail2ban` to have access to the real source IP addresses in order to correctly identify clients. This is achieved by changing the port forwarding driver to [`slirp4netns`][rootless::slirp4netns], which is slower than `builtin` but does preserve the real source IPs.

### Docker with `slirp4netns` port driver

For [rootless mode][rootless::docker] in Docker, create `~/.config/systemd/user/docker.service.d/override.conf` with the following content:

```
[Service]
Environment="DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER=slirp4netns"
```

And then restart the daemon:

```console
$ systemctl --user daemon-reload
$ systemctl --user restart docker
```

!!! note

    This changes the port driver for all rootless containers managed by Docker.

    Per container configuration is not supported, if you need that consider Podman instead.

### Podman with `slirp4netns` port driver

[Rootless Podman][rootless::podman] requires adding the value `slirp4netns:port_handler=slirp4netns` to the `--network` CLI option, or `network_mode` setting in your `docker-compose.yml`.


You must also add the ENV `NETWORK_INTERFACE=tap0`, because Podman uses a [hard-coded interface name][rootless::podman::interface] for `slirp4netns`.


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

!!! note

    `slirp4netns` is not compatible with user-defined networks.

## Manage bans

You can also manage and list the banned IPs with the [`setup.sh`][docs-setupsh] script.

### List bans

```sh
./setup.sh fail2ban
```

### Un-ban

Here `192.168.1.15` is our banned IP.

```sh
./setup.sh fail2ban unban 192.168.1.15
```

[docs-setupsh]: ../setup.sh.md
[github-file-f2bjail]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config-examples/fail2ban-jail.cf
[github-file-f2bconfig]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config-examples/fail2ban-fail2ban.cf
[rootless::rootless-kit]: https://github.com/rootless-containers/rootlesskit
[rootless::port-drivers]: https://github.com/rootless-containers/rootlesskit/blob/v0.14.5/docs/port.md#port-drivers
[rootless::slirp4netns]: https://github.com/rootless-containers/slirp4netns
[rootless::docker]: https://docs.docker.com/engine/security/rootless
[rootless::podman]: https://github.com/containers/podman/blob/v3.4.1/docs/source/markdown/podman-run.1.md#--networkmode---net
[rootless::podman::interface]: https://github.com/containers/podman/blob/v3.4.1/libpod/networking_slirp4netns.go#L264
