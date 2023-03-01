---
title: Usage
---

This pages explains how to get started with DMS, basically explaining how you can use it. The procedure uses Docker Compose as a reference. In our examples, [`/docker-data/dms/config/`](../faq/#what-about-the-docker-datadmsmail-state-folder) on the host is mounted to `/tmp/docker-mailserver/` inside the container.

## Available Images / Tags - Tagging Convention

[CI/CD](https://github.com/docker-mailserver/docker-mailserver/actions) will automatically build, test and push new images to container registries. Currently, the following registries are supported:

1. DockerHub ([`docker.io/mailserver/docker-mailserver`](https://hub.docker.com/r/mailserver/docker-mailserver))
2. GitHub Container Registry ([`ghcr.io/docker-mailserver/docker-mailserver`](https://github.com/docker-mailserver/docker-mailserver/pkgs/container/docker-mailserver))

All workflows are using the tagging convention listed below. It is subsequently applied to all images.

| Event                   | Image Tags                    |
|-------------------------|-------------------------------|
| `push` on `master`      | `edge`                        |
| `push` a tag (`v1.2.3`) | `1.2.3`, `1.2`, `1`, `latest` |

## Get the Tools

!!! note "`setup.sh` Not Required Anymore"

    Since DMS `v10.2.0`, [`setup.sh` functionality](../faq/#how-to-adjust-settings-with-the-user-patchessh-script) is included within the container image. The external convenience script is no longer required if you prefer using `docker exec <CONTAINER NAME> setup <COMMAND>` instead.

Issue the following commands to acquire the necessary files:

``` BASH
DMS_GITHUB_URL='https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master'
wget "${DMS_GITHUB_URL}/docker-compose.yml"
wget "${DMS_GITHUB_URL}/mailserver.env"

# Optional
wget "${DMS_GITHUB_URL}/setup.sh"
chmod a+x ./setup.sh
```

## Create a docker-compose Environment

1. [Install the latest Docker Compose](https://docs.docker.com/compose/install/)
2. Edit `docker-compose.yml` to your liking
    - substitute `mail.example.com` according to your FQDN
    - if you want to use SELinux for the `./docker-data/dms/config/:/tmp/docker-mailserver/` mount, append `-z` or `-Z`
3. Configure the mailserver container to your liking by editing `mailserver.env` ([**Documentation**](https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/)), but keep in mind this `.env` file:
    - [_only_ basic `VAR=VAL`](https://docs.docker.com/compose/env-file/) is supported (**do not** quote your values)
    - variable substitution is **not** supported (e.g. :no_entry_sign: `OVERRIDE_HOSTNAME=$HOSTNAME.$DOMAINNAME` :no_entry_sign:)

!!! info "Podman Support"

    If you're using podman, make sure to read the related [documentation](https://docker-mailserver.github.io/docker-mailserver/edge/config/advanced/podman/)

## Get up and running

### First Things First

!!! danger "Using the Correct Commands For Stopping and Starting DMS"

    **Use `docker compose up / down`, not `docker compose start / stop`**. Otherwise, the container is not properly destroyed and you may experience problems during startup because of inconsistent state.

    Using `Ctrl+C` **is not supported either**!

You are able to get a full overview of how the configuration works by either running:

1. `./setup.sh help` which includes the options of `setup.sh`.
2. `docker run --rm docker.io/mailserver/docker-mailserver:latest setup help` which provides you with all the information on configuration provided "inside" the container itself.

??? info "Usage of `setup.sh` when no DMS Container Is Running"

    If no DMS container is running, any `./setup.sh` command will check online for the `:latest` image tag (the current _stable_ release), performing a `docker pull ...` if necessary followed by running the command in a temporary container:

    ```console
    $ ./setup.sh help
    Image 'docker.io/mailserver/docker-mailserver:latest' not found. Pulling ...
    SETUP(1)

    NAME
        setup - 'docker-mailserver' Administration & Configuration script
    ...

    $ docker run --rm docker.io/mailserver/docker-mailserver:latest setup help
    SETUP(1)

    NAME
        setup - 'docker-mailserver' Administration & Configuration script
    ...
    ```

### Starting for the first time

On first start, you will need to add at least one email account (unless you're using LDAP). You have two minutes to do so, otherwise DMS will shutdown and restart. You can add accounts with the following two methods:

1. Use `setup.sh`: `./setup.sh email add <user@domain>`
2. Run the command directly in the container: `docker exec -ti <CONTAINER NAME> setup email add <user@domain>`

You can then proceed by creating the postmaster alias and by creating DKIM keys.

``` BASH
docker-compose up -d mailserver

# you may add some more users
# for SELinux, use -Z
./setup.sh [-Z] email add <user@domain> [<password>]

# and configure aliases, DKIM and more
./setup.sh [-Z] alias add postmaster@<domain> <user@domain>
```

## Further Miscellaneous Steps

### DNS - DKIM

You can (and you should) generate DKIM keys by running

``` BASH
./setup.sh [-Z] config dkim
```

If you want to see detailed usage information, run

``` BASH
./setup.sh config dkim help
```

In case you're using LDAP, the setup looks a bit different as you do not add user accounts directly. Postfix doesn't know your domain(s) and you need to provide it when configuring DKIM:

``` BASH
./setup.sh config dkim domain '<domain.tld>[,<domain2.tld>]'
```

When keys are generated, you can configure your DNS server by just pasting the content of `config/opendkim/keys/domain.tld/mail.txt` to [set up DKIM](https://mxtoolbox.com/dmarc/dkim/setup/how-to-setup-dkim). See the [documentation](./config/best-practices/dkim.md) for more details.

### Custom User Changes & Patches

If you'd like to change, patch or alter files or behavior of `docker-mailserver`, you can use a script. See [this part of our documentation](./faq.md/#how-to-adjust-settings-with-the-user-patchessh-script) for a detailed explanation.
