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

## Installation in Rootful Mode

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

## Installation in Rootless Mode

Running [rootless containers][podman-docs::rootless-mode] is one of Podman's major features. But due to some restrictions, deploying docker-mailserver in rootless mode is not as easy compared to rootful mode.

- a rootless container is running in a user namespace so you cannot bind ports lower than 1024
- a rootless container's systemd file can only be placed in folder under `~/.config`
- a rootless container can result in an open relay, make sure to read the [security section](#security-in-rootless-mode).

Also notice that Podman's rootless mode is not about running as a non-root user inside the container, but about the mapping of (normal, non-root) host users to root inside the container.

!!! warning

    In order to make rootless DMS work we must modify some settings in the Linux system, it requires some basic linux server knowledge so don't follow this guide if you not sure what this guide is talking about. Podman rootful mode and Docker are still good and security enough for normal daily usage.

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

!!! info "What is a Quadlet?"

    A [Quadlet][podman::quadlet::introduction] file uses the [systemd config format][systemd-docs::config-syntax] which is similar to the INI format.

    [Quadlets define your podman configuration][podman-docs::quadlet::example-configs] (_pods, volumes, networks, images, etc_) which are [adapted into the equivalent systemd service config files][podman::quadlet::generated-output-example] at [boot or when reloading the systemd daemon][podman-docs::config::quadlet-generation] (`systemctl daemon-reload` / `systemctl --user daemon-reload`).

!!! tip "Rootless compatibility"

    Quadlets can [support rootless with a few differences][podman::rootless-differences]:

    - `Network=pasta` configures [`pasta`][network-driver::pasta] as a rootless compatible network driver (_a popular alternative to `slirp4netns`. `pasta` is the default for rootless since Podman v5_).
    - `Restart=always` will auto-start your Quadlet at login. Rootless support requires to enable [lingering][systemd-docs::loginctl::linger] for your user:

        ```bash
        loginctl enable-linger user
        ```
    - [Config locations between rootful vs rootless][podman-docs::quadlet::config-search-path].

#### Example Quadlet file

???+ example

    1. Create your DMS Quadlet at `~/.config/containers/systemd/dms.container` with the example content shown below.
        - Adjust settings like `HostName` as needed. You may prefer a different convention for your `Volume` host paths.
        - Some syntax like systemd specifiers and Podman's `UIDMap` value are explained in detail after this example.
    2. Run [`systemctl --user daemon-reload`][systemd-docs::systemctl::daemon-reload], which will trigger the Quadlet service generator. This command is required whenever you adjust config in `dms.container`.
    3. You should now be able to start the service with `systemctl --user start dms`.

    ```ini title="dms.container"
    [Unit]
    Description="Docker Mail Server"
    Documentation=https://docker-mailserver.github.io/docker-mailserver/latest

    [Service]
    Restart=always
    # Optional - This will run before the container starts:
    # - It ensures all the DMS volumes have the host directories created for you.
    # - For `mkdir` command to leverage the shell brace expansion syntax, you need to run it via bash.
    ExecStartPre=/usr/bin/bash -c 'mkdir -p %h/volumes/%N/{mail-data,mail-state,mail-logs,config}'

    # This section enables the service at generation, avoids requiring `systemctl --user enable dms`:
    # - `multi-user.target` => root
    # - `default.target` => rootless
    [Install]
    WantedBy=default.target

    [Container]
    ContainerName=%N
    HostName=mail.example.com
    Image=docker.io/mailserver/docker-mailserver:latest

    PublishPort=25:25
    PublishPort=143:143
    PublishPort=587:587
    PublishPort=993:993

    # The container UID for root will be mapped to the host UID running this Quadlet service.
    # All other UIDs in the container are mapped via the sub-id range for that user from host configs `/etc/subuid` + `/etc/subgid`.
    UIDMap=+0:@%U

    # Volumes (Base location example: `%h/volumes/%N` => `~/volumes/dms`)
    # NOTE: If your host has SELinux enabled, avoid permission errors by appending the mount option `:Z`.
    Volume=%h/volumes/%N/mail-data:/var/mail
    Volume=%h/volumes/%N/mail-state:/var/mail-state
    Volume=%h/volumes/%N/mail-logs:/var/log/mail
    Volume=%h/volumes/%N/config:/tmp/docker-mailserver
    # Optional - Additional mounts:
    # NOTE: For SELinux, when using the `z` or `Z` mount options:
    #   Take caution if choosing a host location not belonging to your user. Consider using `SecurityLabelDisable=true` instead.
    #   https://docs.podman.io/en/latest/markdown/podman-run.1.html#volume-v-source-volume-host-dir-container-dir-options
    Volume=%h/volumes/certbot/certs:/etc/letsencrypt:ro

    # Podman can create a timer (defaults to daily at midnight) to check the `registry` or `local` storage for detecting if the
    # image tag points to a new digest, if so it updates the image and restarts the service (similar to `containrrr/watchtower`):
    # https://docs.podman.io/en/latest/markdown/podman-auto-update.1.html
    AutoUpdate=registry

    # Podman Quadlet has a better alternative instead of a volume directly bind mounting `/etc/localtime` to match the host TZ:
    # https://docs.podman.io/en/latest/markdown/podman-run.1.html#tz-timezone
    # NOTE: Should the host modify the system TZ, neither approach will sync the change to the `/etc/localtime` inside the running container.
    Timezone=local

    Environment=SSL_TYPE=letsencrypt
    # NOTE: You may need to adjust the default `NETWORK_INTERFACE`:
    # https://docker-mailserver.github.io/docker-mailserver/latest/config/environment/#network_interface
    #Environment=NETWORK_INTERFACE=enp1s0
    #Environment=NETWORK_INTERFACE=tap0
    ```

??? info "Systemd specifiers"

    Systemd has a [variety of specifiers][systemd-docs::config-specifiers] (_prefixed with `%`_) that help manage configs.
    
    Here are the ones used in the Quadlet config example:

    - **`%h`:** Location of the users home directory. Use this instead of `~` (_which would only work in a shell, not this config_).
    - **`%N`:** Represents the unit service name, which is taken from the filename excluding the extension (_thus `dms.container` => `dms`_).
    - **`%U`:** The UID of the user running this service. The next section details the relevance with `UIDMap`.

    ---

    If you prefer the conventional XDG locations, you may prefer `%D` + `%E` + `%S` as part of your `Volume` host paths.

Stopping the service with systemd will result in the container being removed. Restarting will use the existing container, which is however not recommended. You do not need to enable services with Quadlet.

Start container:

`systemctl --user start dockermailserver`

Stop container:

`systemctl --user stop dockermailserver`

Using root with machinectl (used for some Ansible versions):

`machinectl -q shell yourrootlessuser@ /bin/systemctl --user start dockermailserver`

#### Mapping ownership between container and host users

Podman supports a few different approaches for this functionality. For rootless Quadlets you will likely want to use `UIDMap` (_`GIDMap` will use this same mapping by default_).

- `UIDMap` + `GIDMap` works by mapping user and group IDs from a container, to IDs associated for a user on the host [configured in `/etc/subuid` + `/etc/subgid`][podman-docs::rootless-mode] (_this isn't necessary for rootful Podman_).
- Each mapping must be unique, thus only a single container UID can map to your rootless UID on the host. Every other container UID mapped must be within the configured range from `/etc/subuid`.
- Rootless containers have one additional level of mapping involved. This is an offset from their `/etc/subuid` entry starting from `0`, but can be inferred when the intended UID on the host is prefixed with `@`

??? tip "Why should I prefer `UIDMap=+0:@%U`? How does the `@` syntax work?"

    The most common case is to map the containers root user (UID `0`) to your host user ID.

    For a rootless user with the UID `1000` on the host, any of the following `UIDMap` values are equivalent:

    - **`UIDMap=+0:0`:** The 1st `0` is the container root ID and the 2nd `0` refers to host mapping ID. For rootless the mapping ID is an indirect offset to their user entry in `/etc/subuid` where `0` maps to their host user ID, while `1` or higher maps to the users subuid range.
    - **`UIDMap=+0:@1000`:** A rootless Quadlet can also use `@` as a prefix which Podman will then instead lookup as the host ID in `/etc/subuid` to get the offset value. If the host user ID was `1000`, then `@1000` would resolve that to `0`.
    - **`UIDMap=+0:@%U`:** Instead of providing the explicit rootless UID, a better approach is to leverage `%U` (_a [systemd specifier][systemd-docs::config-specifiers]_) which will resolve to the UID of your rootless user that starts the Quadlet service.

??? tip "What is the `+` syntax used with `UIDMap`?"

    Prefixing the container ID with `+` is a a podman feature similar to `@`, which ensures `/etc/subuid` is mapped fully.

    For example `UIDMap=+5000:@%U` is the short-hand equivalent to:

    ```ini
    UIDMap=5000:0:1
    UIDMap=0:1:5000
    UIDMap=5001:5001:60536
    ```

    The third value is the amount of IDs to map from the `container:host` pair as an offset/range. It defaults to `1`.

    In addition to our explicit `5000:0` mapping, the `+` ensures:

    - That we have a mapping of all container ID prior to `5000` to IDs from our rootless user entry in `/etc/subuid` on the host.
    - It also adds a mapping after this value for the remainder of the range configured in `/etc/subuid` which covers the `nobody` user in the container.

    Within the container you can view these mappings via `cat /proc/self/uid_map`.

??? warning "Impact on disk usage of images with Rootless"

    **NOTE:** This should not usually be a concern, but is documented here to explain the impact of creating new user namespaces (_such as by running a container with settings like `UIDMap` that differ between runs_).

    ---

    Rootless containers [perform a copy of the image with `chown`][caveat::podman::rootless::image-chown] during the first pull/run of the image.

    - The larger the image to copy, the longer the initial delay on first use.
    - This process will be repeated if the `UIDMap` / `GIDMap` settings are changed to a value that has not been used previously (_accumulating more disk usage with additional image layer copies_).
    - Only when the original image is removed will any of these associated `chown` image copies be purged from storage.

    When you specify a `UIDMap` like demonstrated in the earlier tip for the `+` syntax with `UIDMap=+0:5000`, if the `/proc/self/uid_map` shows a row with the first two columns as equivalent then no excess `chown` should be applied.

    - `UIDMap=+0:@%U` is equivalent from ID 2 onwards.
    - `UIDMap=+5000:@%U` is equivalent from ID 5001 onwards. This is relevant with DMS as the container UID 200 is assigned to ClamAV, the offset introduced will now incur a `chown` copy of 230MB.

## Start DMS container at boot

Unlike Docker, Podman is daemonless thus containers do not start at boot. You can create your own systemd service to schedule this or use the Podman CLI.

!!! warning "`podman generate systemd` is deprecated"

    The [`podman generate systemd`][podman-docs::cli::generate-systemd] command has been deprecated [since Podman v4.7][gh::podman::release-4.7] (Sep 2023) in favor of Quadlets (_available [since Podman v4.4][gh::podman::release-4.4]_).

!!! example "Create a systemd service"

    Use the Podman CLI to generate a systemd service at the rootful or rootless location.

    === "Rootful"

        ```bash
        podman generate systemd mailserver > /etc/systemd/system/mailserver.service
        systemctl daemon-reload
        systemctl enable --now mailserver.service
        ```

    === "Rootless"

        ```bash
        podman generate systemd mailserver > ~/.config/systemd/user/mailserver.service
        systemctl --user daemon-reload
        systemctl enable --user --now mailserver.service
        ```

A systemd user service will only start when that specific user logs in and stops when after log out. To instead allow user services to run when that user has no active session running run:

```bash
loginctl enable-linger <username>
```

### Security in Rootless Mode

In rootless mode, podman resolves all incoming IPs as localhost, which results in an open gateway in the default configuration. There are two workarounds to fix this problem, both of which have their own drawbacks.

#### Enforce authentication from localhost

The `PERMIT_DOCKER` variable in the `mailserver.env` file allows to specify trusted networks that do not need to authenticate. If the variable is left empty, only requests from localhost and the container IP are allowed, but in the case of rootless podman any IP will be resolved as localhost. Setting `PERMIT_DOCKER=none` enforces authentication also from localhost, which prevents sending unauthenticated emails.

#### Use the `pasta` network driver

Since [Podman 5.0][gh::podman::release-5.0] the default rootless network driver is now `pasta` instead of `slirp4netns`. These two drivers [have some differences][rhel-docs::podman::slirp4netns-vs-pasta]:

> Notable differences of `pasta` network mode compared to `slirp4netns` include:
> 
> - `pasta` supports IPv6 port forwarding.
> - `pasta` is more efficient than `slirp4netns`.
> - `pasta` copies IP addresses from the host, while `slirp4netns` uses a predefined IPv4 address.
> - `pasta` uses an interface name from the host, while `slirp4netns` uses `tap0` as an interface name.
> - `pasta` uses the gateway address from the host, while `slirp4netns` defines its own gateway address and uses NAT.

#### Use the `slip4netns` network driver

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
[network-driver::pasta]: https://passt.top/passt/about/#pasta
[gh::podman::release-4.4]: https://github.com/containers/podman/releases/tag/v4.4.0
[gh::podman::release-4.7]: https://github.com/containers/podman/releases/tag/v4.7.0
[gh::podman::release-5.0]: https://github.com/containers/podman/releases/tag/v5.0.0
[rhel-docs::podman::slirp4netns-vs-pasta]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/assembly_communicating-among-containers_building-running-and-managing-containers#differences-between-slirp4netns-and-pasta_assembly_communicating-among-containers
[firewalld-port-forwarding]: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/securing_networks/using-and-configuring-firewalld_securing-networks#port-forwarding_using-and-configuring-firewalld

[podman::quadlet::introduction]: https://mo8it.com/blog/quadlet/
[podman::quadlet::generated-output-example]: https://blog.while-true-do.io/podman-quadlets/#writing-quadlets
[podman::rootless-differences]: https://matduggan.com/replace-compose-with-quadlet/#rootless

[podman-docs::rootless-mode]: https://docs.podman.io/en/stable/markdown/podman.1.html#rootless-mode
[podman-docs::cli::generate-systemd]: https://docs.podman.io/en/latest/markdown/podman-generate-systemd.1.html
[podman-docs::quadlet::example-configs]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html#examples
[podman-docs::config::quadlet-generation]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html#description
[podman-docs::quadlet::config-search-path]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html#podman-rootful-unit-search-path

[systemd-docs::config-syntax]: https://www.freedesktop.org/software/systemd/man/latest/systemd.syntax.html
[systemd-docs::config-specifiers]: https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html#Specifiers
[systemd-docs::loginctl::linger]: https://www.freedesktop.org/software/systemd/man/latest/loginctl.html#enable-linger%20USER%E2%80%A6
[systemd-docs::systemctl::daemon-reload]: https://www.freedesktop.org/software/systemd/man/latest/systemctl.html#daemon-reload

[caveat::podman::rootless::image-chown]: https://github.com/containers/podman/issues/16541#issuecomment-1352790422
