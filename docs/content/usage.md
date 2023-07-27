---
title: Usage
---

This pages explains how to get started with DMS. The guide uses Docker Compose as a reference. In our examples, a volume mounts the host location [`docker-data/dms/config/`][docs-dms-config-volume] to `/tmp/docker-mailserver/` inside the container.

[docs-dms-config-volume]: ./faq.md#what-about-the-docker-datadmsconfig-directory

## Preliminary Steps

Before you can get started with deploying your own mail server, there are some requirements to be met:

1. You need to have a host that you can manage.
2. You need to own a domain, and you need to able to manage DNS for this domain.

### Host Setup

There are a few requirements for a suitable host system:

1. The host should have a static IP address; otherwise you will need to dynamically update DNS (undesirable due to DNS caching)
2. The host should be able to send/receive on the [necessary ports for mail][docs-ports-overview]
3. You should be able to set a `PTR` record for your host; security-hardened mail servers might otherwise reject your mail server as the IP address of your host does not resolve correctly/at all to the DNS name of your server.

!!! note "About the Container Runtime"

    On the host, you need to have a suitable container runtime (like _Docker_ or _Podman_) installed. We assume [_Docker Compose_][docker-compose] is [installed][docker-compose-installation]. We have aligned file names and configuration conventions with the latest [Docker Compose (currently V2) specification][docker-compose-specification].

    If you're using podman, make sure to read the related [documentation][docs-podman].

[docs-ports-overview]: ./config/security/understanding-the-ports.md#overview-of-email-ports
[docker-compose]: https://docs.docker.com/compose/
[docker-compose-installation]: https://docs.docker.com/compose/install/
[docker-compose-specification]: https://docs.docker.com/compose/compose-file/
[docs-podman]: ./config/advanced/podman.md

### Minimal DNS Setup

The DNS setup is a big and essential part of the whole setup. There is a lot of confusion for newcomers and people starting out when setting up DNS. This section provides an example configuration and supplementary explanation.  We expect you to be at least a bit familiar with DNS, what it does and what the individual record types are.

Now let's say you just bought `example.com` and you want to be able to send and receive e-mails for the address `test@example.com`. On the most basic level, you will need to

1. set an `MX` record for your domain `example.com` - in our example, the MX record contains `mail.example.com`
2. set an `A` record that resolves the name of your mail server - in our example, the A record contains `11.22.33.44`
3. (in a best-case scenario) set a `PTR` record that resolves the IP of your mail server - in our example, the PTR contains `mail.example.com`

We will later dig into DKIM, DMARC & SPF, but for now, these are the records that suffice in getting you up and running. Here is a short explanation of what the records do:

- The **MX record** tells everyone which (DNS) name is responsible for e-mails on your domain.
    Because you want to keep the option of running another service on the domain name itself, you run your mail server on `mail.example.com`.
    This does not imply your e-mails will look like `test@mail.example.com`, the DNS name of your mail server is decoupled of the domain it serves e-mails for.
    In theory, you mail server could even serve e-mails for `test@some-other-domain.com`, if the MX record for `some-other-domain.com` points to `mail.example.com`.
- The **A record** tells everyone which IP address the DNS name `mail.example.com` resolves to.
- The **PTR record** is the counterpart of the A record, telling everyone what name the IP address `11.22.33.44` resolves to.

!!! note "About The Mail Server's Fully Qualified Domain Name"

    The mail server's fully qualified domain name (FQDN) in our example above is `mail.example.com`. Please note though that this is more of a convention, and not due to technical restrictions. One could also run the mail server

    1. on `foo.example.com`: you would just need to change your `MX` record;
    2. on `example.com` directly: you would need to change your `MX` record and probably [read our docs on bare domain setups][docs-faq-bare-domain], as these setups are called "bare domain" setups.

    The FQDN is what is relevant for TLS certificates, it has no (inherent/technical) relation to the email addresses and accounts DMS manages. That is to say: even though DMS runs on `mail.example.com`, or `foo.example.com`, or `example.com`, there is nothing that prevents it from managing mail for `barbaz.org` - `barbaz.org` will just need to set its `MX` record to `mail.example.com` (or `foo.example.com` or `example.com`).

    [docs-faq-bare-domain]: ./faq.md#can-i-use-a-nakedbare-domain-ie-no-hostname

If you setup everything, it should roughly look like this:

```console
$ dig @1.1.1.1 +short MX example.com
mail.example.com
$ dig @1.1.1.1 +short A mail.example.com
11.22.33.44
$ dig @1.1.1.1 +short -x 11.22.33.44
mail.example.com
```

## Deploying the Actual Image

### Tagging Convention

To understand which tags you should use, read this section carefully. [Our CI][github-ci] will automatically build, test and push new images to the following container registries:

1. DockerHub ([`docker.io/mailserver/docker-mailserver`][dockerhub-image])
2. GitHub Container Registry ([`ghcr.io/docker-mailserver/docker-mailserver`][ghcr-image])

All workflows are using the tagging convention listed below. It is subsequently applied to all images.

| Event                   | Image Tags                    |
|-------------------------|-------------------------------|
| `push` on `master`      | `edge`                        |
| `push` a tag (`v1.2.3`) | `1.2.3`, `1.2`, `1`, `latest` |

[github-ci]: https://github.com/docker-mailserver/docker-mailserver/actions
[dockerhub-image]: https://hub.docker.com/r/mailserver/docker-mailserver
[ghcr-image]: https://github.com/docker-mailserver/docker-mailserver/pkgs/container/docker-mailserver

### Get All Files

Issue the following commands to acquire the necessary files:

``` BASH
DMS_GITHUB_URL="https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master"
wget "${DMS_GITHUB_URL}/compose.yaml"
wget "${DMS_GITHUB_URL}/mailserver.env"
```

### Configuration Steps

1. First edit `compose.yaml` to your liking
    - Substitute `mail.example.com` according to your FQDN.
    - If you want to use SELinux for the `./docker-data/dms/config/:/tmp/docker-mailserver/` mount, append `-z` or `-Z`.
2. Then configure the environment specific to the mail server by editing [`mailserver.env`][docs-environment], but keep in mind that:
    - only [basic `VAR=VAL`][docker-compose-env-file] is supported
    - do not quote your values
    - variable substitution is not supported, e.g. `OVERRIDE_HOSTNAME=$HOSTNAME.$DOMAINNAME` does not work

[docs-environment]: ./config/environment.md
[docker-compose-env-file]: https://docs.docker.com/compose/env-file/

### Get Up and Running

!!! danger "Using the Correct Commands For Stopping and Starting DMS"

    **Use `docker compose up / down`, not `docker compose start / stop`**. Otherwise, the container is not properly destroyed and you may experience problems during startup because of inconsistent state.

    Using `Ctrl+C` **is not supported either**!

For an overview of commands to manage DMS config, run: `docker exec -it <CONTAINER NAME> setup help`.

??? info "Usage of `setup.sh` when no DMS Container Is Running"

    We encourage you to directly use `setup` inside the container (like shown above). If you still want to use `setup.sh`, here's some information about it.

    If no DMS container is running, any `./setup.sh` command will check online for the `:latest` image tag (the current _stable_ release), performing a `docker pull ...` if necessary followed by running the command in a temporary container:

    ```console
    $ ./setup.sh help
    Image 'ghcr.io/docker-mailserver/docker-mailserver:latest' not found. Pulling ...
    SETUP(1)

    NAME
        setup - 'docker-mailserver' Administration & Configuration script
    ...

    $ docker run --rm ghcr.io/docker-mailserver/docker-mailserver:latest setup help
    SETUP(1)

    NAME
        setup - 'docker-mailserver' Administration & Configuration script
    ...
    ```

On first start, you will need to add at least one email account (unless you're using LDAP). You have two minutes to do so, otherwise DMS will shutdown and restart. You can add accounts by running `docker exec -ti <CONTAINER NAME> setup email add user@example.com`. **That's it! It really is that easy**.

## Further Miscellaneous Steps

### Setting up TLS

You definitely want to setup TLS. Please refer to [our documentation about TLS][docs-tls].

[docs-tls]: ./config/security/ssl.md

### Aliases

You should add at least one [alias][docs-aliases], the [_postmaster alias_][docs-env-postmaster]. This is a common convention, but not strictly required.

[docs-aliases]: ./config/user-management.md#aliases
[docs-env-postmaster]: ./config/environment.md#postmaster_address

```bash
docker exec -ti <CONTAINER NAME> setup alias add postmaster@example.com user@example.com
```

### Advanced DNS Setup - DKIM, DMARC & SPF

You will very likely want to configure your DNS with these TXT records: [SPF, DKIM, and DMARC][cloudflare-spf-dkim-dmarc]. We also ship a [dedicated page in our documentation][docs-dkim-dmarc-spf] about the setup of DKIM, DMARC & SPF.

[cloudflare-spf-dkim-dmarc]: https://www.cloudflare.com/learning/email-security/dmarc-dkim-spf/
[docs-dkim-dmarc-spf]: ./config/best-practices/dkim_dmarc_spf.md

### Custom User Changes & Patches

If you'd like to change, patch or alter files or behavior of DMS, you can use a script. See [this part of our documentation][docs-user-patches] for a detailed explanation.

[docs-user-patches]: ./faq.md#how-to-adjust-settings-with-the-user-patchessh-script

## Testing

Here are some tools you can use to verify your configuration:

1. [MX Toolbox](https://mxtoolbox.com/SuperTool.aspx)
2. [DMARC Analyzer](https://www.mimecast.com/products/dmarc-analyzer/spf-record-check/)
3. [mail-tester.com](https://www.mail-tester.com/)
4. [multiRBL.valli.org](https://multirbl.valli.org/)
5. [internet.nl](https://internet.nl/test-mail/)
