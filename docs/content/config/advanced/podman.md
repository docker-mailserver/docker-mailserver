---
title: 'Advanced | Podman'
---

## Introduction

Podman is a daemonless container engine for developing, managing, and running OCI Containers on your Linux System.

!!! warning "About Support for Podman"

    Please note that Podman **is not** officially supported as DMS is built and verified on top of the _Docker Engine_. This content is entirely community supported. If you find errors, please open an issue and provide a PR.

!!! warning "About this Guide"

    This guide was tested with Fedora 34 using `systemd` and `firewalld`. Moreover, it requires Podman version >= 3.2. You may be able to substitute `dnf` - Fedora's package manager - with others such as `apt`.

!!! warning "About Security"

    Running podman in rootless mode requires additional modifications in order to keep your mailserver secure.
    Make sure to read the related documentation.

## Installation in Rootfull Mode

While using Podman, you can just manage docker-mailserver as what you did with Docker. Your best friend `setup.sh` includes the minimum code in order to support Podman since it's 100% compatible with the Docker CLI.

The installation is basically the same. Podman v3.2 introduced a RESTful API that is 100% compatible with the Docker API, so you can use Docker Compose with Podman easily. Install Podman and Docker Compose with your package manager first.

```bash
sudo dnf install podman docker-compose
```

Then enable `podman.socket` using `systemctl`.

```bash
systemctl enable --now podman.socket
```

This will create a unix socket locate under `/run/podman/podman.sock`, which is the entrypoint of Podman's API. Now, configure docker-mailserver and start it.

```bash
export DOCKER_HOST="unix:///run/podman/podman.sock"
docker compose up -d mailserver
docker compose ps
```

You should see that docker-mailserver is running now.

### Self-start in Rootfull Mode

Podman is daemonless, that means if you want docker-mailserver self-start while boot up the system, you have to generate a systemd file with Podman CLI.

```bash
podman generate systemd mailserver > /etc/systemd/system/mailserver.service
systemctl daemon-reload
systemctl enable --now mailserver.service
```

## Installation in Rootless Mode

Running rootless containers is one of Podman's major features. But due to some restrictions, deploying docker-mailserver in rootless mode is not as easy compared to rootfull mode.

- a rootless container is running in a user namespace so you cannot bind ports lower than 1024
- a rootless container's systemd file can only be placed in folder under `~/.config`
- a rootless container can result in an open relay, make sure to read the [security section](#security-in-rootless-mode).

Also notice that Podman's rootless mode is not about running as a non-root user inside the container, but about the mapping of (normal, non-root) host users to root inside the container.

!!! warning

    In order to make rootless DMS work we must modify some settings in the Linux system, it requires some basic linux server knowledge so don't follow this guide if you not sure what this guide is talking about. Podman rootfull mode and Docker are still good and security enough for normal daily usage.

First, enable `podman.socket` in systemd's userspace with a non-root user.

```bash
systemctl enable --now --user podman.socket
```

The socket file should be located at `/var/run/user/$(id -u)/podman/podman.sock`. Then, modify `compose.yaml` to make sure all ports are bindings are on non-privileged ports.

```yaml
services:
  mailserver:
    ports:
      - "10025:25"   # SMTP  (explicit TLS => STARTTLS)
      - "10143:143"  # IMAP4 (explicit TLS => STARTTLS)
      - "10465:465"  # ESMTP (implicit TLS)
      - "10587:587"  # ESMTP (explicit TLS => STARTTLS)
      - "10993:993"  # IMAP4 (implicit TLS)
```

Then, setup your `mailserver.env` file follow the documentation and use Docker Compose to start the container.

```bash
export DOCKER_HOST="unix:///var/run/user/$(id -u)/podman/podman.sock"
docker compose up -d mailserver
docker compose ps
```

### Rootless Quadlet

!!! warning "`podman generate systemd` is deprecated"

    [`podman generate systemd`][podman-docs::cli::generate-systemd] has been deprecated in favor of Quadlets (_since Podman v4.4_).

!!! info "What is a Quadlet?"

    A [Quadlet][podman::quadlet::introduction] file uses the [systemd config format](https://www.freedesktop.org/software/systemd/man/latest/systemd.syntax.html) which is similar to the INI format.

    [Quadlets define your podman configuration][podman-docs::quadlet::example-configs] (_pods, volumes, networks, images, etc_) which are [adapted into the equivalent systemd service config files][podman::quadlet::generated-output-example] at [boot or when reloading the systemd daemon][podman-docs::config::quadlet-generation] (`systemctl daemon-reload` / `systemctl --user daemon-reload`).

[podman-docs::cli::generate-systemd]: https://docs.podman.io/en/latest/markdown/podman-generate-systemd.1.html
[podman-docs::quadlet::example-configs]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html#examples
[podman-docs::config::quadlet-generation]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html#description
[podman::quadlet::introduction]: https://mo8it.com/blog/quadlet/
[podman::quadlet::generated-output-example]: https://blog.while-true-do.io/podman-quadlets/#writing-quadlets

!!! tip "Rootless compatibility"

    Quadlets can [support rootless with a few differences][podman::rootless-differences]:

    - `Network=pasta` configures [`pasta`][network-driver::pasta] as a rootless compatible network driver (_a popular alternative to `slirp4netns`. `pasta` is the default for rootless since Podman v5_).
    - `Restart=always` will auto-start your Quadlet at login, rootless support requires to enable [lingering][systemd-docs::loginctl::linger] for your user:

        ```bash
        loginctl enable-linger user
        ```
    - [Config locations between rootful vs rootless][podman-docs::quadlet::config-search-path].

[podman::rootless-differences]: https://matduggan.com/replace-compose-with-quadlet/#rootless
[network-driver::pasta]: https://passt.top/passt/about/#pasta
[systemd-docs::loginctl::linger]: https://www.freedesktop.org/software/systemd/man/latest/loginctl.html#enable-linger%20USER%E2%80%A6
[podman-docs::quadlet::config-search-path]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html#podman-rootful-unit-search-path


#### Example Quadlet file

We have to use the .container extension for the quadlet generator to pick up the service.
Because docker-mailserver uses multiple users inside the container, we will either have to use our own user as root, resulting in our e-mails being owned by a subuid. Alternatively, using UIDMap we can map our rootless user to UID 5000 in the container who owns our e-mails. Using UIDMap also maps root user 0 inside the container to an available sub-uid of our rootless user. Otherwise the container will not have permission to configure itself.

The example uses `Network=pasta` to use the pasta network driver, which will replace `slirp4netns`.

`dockermailservice.container`

```
[Service]
Restart=always

[Install]
WantedBy=default.target

[Unit]
Wants=network-online.target 
After=network-online.target

[Container]
ContainerName=dms
HostName=example.com
Image=docker.io/mailserver/docker-mailserver:latest 
# DMS uses uid 5000 for mailstate, but creates other folders for different users, which will be mapped to different sub-uids
UIDMap=5000:0:1
UIDMap=0:1:5000
UIDMap=5001:5001:60536
Network=pasta
PublishPort=25:25
PublishPort=143:143
PublishPort=587:587
PublishPort=993:993

# Volumes
Volume=/tank/dms/certs:/tmp/ssl
Volume=/tank/dms/maildata:/var/mail
Volume=/tank/dms/mailstate:/var/mail-state
Volume=/tank/dms/maillogs:/var/log/mail
Volume=/tank/dms/config:/tmp/docker-mailserver/

# If you want to use podmans auto-update service:
AutoUpdate=registry 

# Environment variables
# General Settings

Environment=HOSTNAME=example
Environment=DOMAINNAME=example.com
Environment=CONTAINER_NAME=dockermailserver
...
```
Stopping the service with systemd will result in the container being removed. Restarting will use the existing container, which is however not recommended. You do not need to enable services with Quadlet.

Start container:

`systemctl --user start dockermailserver`

Stop container:

`systemctl --user stop dockermailserver`

Using root with machinectl (used for some Ansible versions):

`machinectl -q shell yourrootlessuser@ /bin/systemctl --user start dockermailserver`

### Security in Rootless Mode

In rootless mode, podman resolves all incoming IPs as localhost, which results in an open gateway in the default configuration. There are two workarounds to fix this problem, both of which have their own drawbacks.

#### Enforce authentication from localhost

The `PERMIT_DOCKER` variable in the `mailserver.env` file allows to specify trusted networks that do not need to authenticate. If the variable is left empty, only requests from localhost and the container IP are allowed, but in the case of rootless podman any IP will be resolved as localhost. Setting `PERMIT_DOCKER=none` enforces authentication also from localhost, which prevents sending unauthenticated emails.

#### Use the pasta network driver
As of podman 5.0 pasta is the default network driver of rootless containers. This will have the same functionality and caveats as the `slirp4netns` driver. You do not need to set an interface name.

#### Use the slip4netns network driver

The second workaround is slightly more complicated because the `compose.yaml` has to be modified.
As shown in the [fail2ban section][docs::fail2ban::rootless] the `slirp4netns` network driver has to be enabled.
This network driver enables podman to correctly resolve IP addresses but it is not compatible with
user defined networks which might be a problem depending on your setup.

[Rootless Podman][rootless::podman] requires adding the value `slirp4netns:port_handler=slirp4netns` to the `--network` CLI option, or `network_mode` setting in your `compose.yaml`.

You must also add the ENV `NETWORK_INTERFACE=tap0`, because Podman uses a [hard-coded interface name][rootless::podman::interface] for `slirp4netns`.

!!! example

    ```yaml
    services:
      mailserver:
        network_mode: "slirp4netns:port_handler=slirp4netns"
        environment:
          - NETWORK_INTERFACE=tap0
          ...
    ```

!!! note

    `podman-compose` is not compatible with this configuration.

### Self-start in Rootless Mode

Generate a systemd file with the Podman CLI.

```bash
podman generate systemd mailserver > ~/.config/systemd/user/mailserver.service
systemctl --user daemon-reload
systemctl enable --user --now mailserver.service
```

Systemd's user space service is only started when a specific user logs in and stops when you log out. In order to make it to start with the system, we need to enable linger with `loginctl`

```bash
loginctl enable-linger <username>
```

Remember to run this command as root user.

### Port Forwarding

When it comes to forwarding ports using `firewalld`, see [these port forwarding docs][firewalld-port-forwarding] for more information.

```bash
firewall-cmd --permanent --add-forward-port=port=<25|143|465|587|993>:proto=<tcp>:toport=<10025|10143|10465|10587|10993>
...

# After you set all ports up.
firewall-cmd --reload
```

Notice that this will only open the access to the external client. If you want to access privileges port in your server, do this:

```bash
firewall-cmd --permanent --direct --add-rule <ipv4|ipv6> nat OUTPUT 0 -p <tcp|udp> -o lo --dport <25|143|465|587|993> -j REDIRECT --to-ports <10025|10143|10465|10587|10993>
...
# After you set all ports up.
firewall-cmd --reload
```

Just map all the privilege port with non-privilege port you set in compose.yaml before as root user.

[docs::fail2ban::rootless]: ../security/fail2ban.md#rootless-container
[rootless::podman]: https://github.com/containers/podman/blob/v3.4.1/docs/source/markdown/podman-run.1.md#--networkmode---net
[rootless::podman::interface]: https://github.com/containers/podman/blob/v3.4.1/libpod/networking_slirp4netns.go#L264
[firewalld-port-forwarding]: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/securing_networks/using-and-configuring-firewalld_securing-networks#port-forwarding_using-and-configuring-firewalld
