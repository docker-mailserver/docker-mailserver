---
title: 'Advanced | Podman'
---

## Introduction

Podman is a daemonless container engine for developing, managing, and running OCI Containers on your Linux System.

!!! warning "About Support for Podman"

    Please note that Podman **is not** officially supported cause the whole project is building and verifying on top of Docker and Docker-compose.

    This content is entirely community-supported. If you find errors, please open an issue and provide a PR.

!!! warning "System Limitation"

    This guide only tested under Fedora 34 with systemd and firewalld. Also it require podman version >= 3.2.

## Root Mode

while using podman, you can just manage docker-mailserver as what you did with docker. Your best friend setup.sh include the minimum code in order to support podman since it's 100% compatible with Docker CLI.

And for the installation is also basically the same. Podman v3.2 introduced a RESTful API that is 100% compatible with Docker API, so you could just use docker-compose with podman without pain.

### Installnation

Install podman and docker-compose with your package manager first.

```
sudo dnf install podman docker-compose
```

Them enable `podman.socket` using systemctl.

```
systemctl enable --now podman.socket
```

This will create a unix socket locate under `/run/podman/podman.sock`, which is the entrypoint of podman's API.

Then setup your `mailserver.env` file follow the document and use docker-compose to boot up the container.

```
export DOCKER_HOST="unix:/run/podman/podman.sock" # Specify API location.
docker-compose up -d mailserver
docker-compose ps
```

You should see that docker-mailserver is running now.

### Self-start

podman is daemonless, that means if you want docker-mailserver self-start while boot up the system, you have to generate a systemd file with podman CLI.

```
podman generate systemd mailserver > /etc/systemd/system/mailserver.service
systemctl daemon-reload
systemctl enable --now mailserver.service
```

## Root-less Mode

Root-less container is one of podman's major feature. But due to some restrictions, deploying docker-mailserver in root-less mode is not as easy as root mode.

- Root-less container is running in user namespace so you can't bind port under 1024.
- Root-less container's systemd file can only pleaced in folder under `~/.config`.

!!! warning "Warning"
    In order to make root-less mailserver work we must modify some settings in the Linux system, it requires some basic linux server knowledge so don't follow this guide if you not sure what this guide is talking about. Podman root mode and Docker are still good and security enough for normal daily usage.

### Installnation

First, enable `podman.socket` in systemd's userspace with a non-root user.

```
systemctl enable --now --user podman.socket
```

The socket file should locate at `/var/run/user/<uid>/podman/podman.sock`, in this case, uid = 1000.

Then modify `docker-compose.yml` file to make sure all ports are binding on non-privilege port.

```
services:
  mailserver:
    ports:
      - "10025:25"    # SMTP  (explicit TLS => STARTTLS)
      - "10143:143"  # IMAP4 (explicit TLS => STARTTLS)
      - "10465:465"  # ESMTP (implicit TLS)
      - "10587:587"  # ESMTP (explicit TLS => STARTTLS)
      - "10993:993"  # IMAP4 (implicit TLS)
```

Then setup your `mailserver.env` file follow the document and use docker-compose to boot up the container.

```
export DOCKER_HOST="unix:/var/run/user/1000/podman/podman.sock" # Specify API location.
docker-compose up -d mailserver
docker-compose ps
```

### Port Forwarding

About how to forward port using firewalld, see [here](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/securing_networks/using-and-configuring-firewalld_securing-networks#port-forwarding_using-and-configuring-firewalld) for more infomation.

```
firewall-cmd --permanent --add-forward-port=port=<25|143|465|587|993>:proto=<tcp>:toport=<10025|10143|10465|10587|10993>
```

Just map all the privilege port with non-privilege port you set in docker-compose.yml before as root user.

### Self-start

Generate systemd file with podman CLI.

```
podman generate systemd mailserver > ~/.config/systemd/user/mailserver.service
systemctl --user daemon-reload
systemctl enable --user --now mailserver.service
```

Systemd user space service is only started when a specific user logs in and stops when you log out. In order to make it to start with the system, we need to enable linger with `loginctl`

```
loginctl enable-linger <username>
```

Remember to run this command as root user.