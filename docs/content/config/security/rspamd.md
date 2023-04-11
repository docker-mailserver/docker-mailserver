---
title: 'Security | Rspamd'
---

!!! warning "The current state of Rspamd integration into DMS"

    Recent pull requests have stabilized integration of Rspamd to a point that we encourage users to test the feature. We are confident that there are no major bugs in our integration that make using Rspamd infeasible. Please note that there may still be changes ahead as integration is still work in progress!

    We expect to stabilize this feature with version `v12.1.0`.

## About

Rspamd is a ["fast, free and open-source spam filtering system"][homepage]. DMS integrates Rspamd like any other service. We provide a very simple but easy to maintain setup of Rspamd.

If you want to have a look at the default configuration files for Rspamd that DMS packs, navigate to [`target/rspamd/` inside the repository][dms-default-configuration]. Please consult the [section "The Default Configuration"](#the-default-configuration) section down below for a written overview.

!!! note "AMD64 vs ARM64"

    We are currently doing a best-effort installation of Rspamd for ARM64 (from the Debian backports repository for Debian 11). The current version difference as of 1st Apr 2023: AMD64 is at version 3.5 | ARM64 is at version 3.4.

## Related Environment Variables

The following environment variables are related to Rspamd:

1. [`ENABLE_RSPAMD`](../environment.md#enable_rspamd)
2. [`ENABLE_RSPAMD_REDIS`](../environment.md#enable_rspamd_redis)
3. [`RSPAMD_GREYLISTING`](../environment.md#rspamd_greylisting)
4. [`RSPAMD_LEARN`](../environment.md#rspamd_learn)
5. [`MOVE_SPAM_TO_JUNK`](../environment.md#move_spam_to_junk)

With these variables, you can enable Rspamd itself and you can enable / disable certain features related to Rspamd.

## The Default Configuration

### Mode of Operation

The proxy worker operates in [self-scan mode][proxy-self-scan-mode]. This simplifies the setup as we do not require a normal worker. You can easily change this though by [overriding the configuration by DMS](#providing-custom-settings-overriding-settings).

DMS does not set a default password for the controller worker. You may want to do that yourself. In setups where you already have an authentication provider in front of the Rspamd webpage, you may want to [set the `secure_ip ` option to `"0.0.0.0/0"` for the controller worker](#with-the-help-of-a-custom-file) to disable password authentication inside Rspamd completely.

### Persistence with Redis

When Rspamd is enabled, we implicitly also start an instance of Redis in the container. Redis is configured to persist it's data via RDB snapshots to disk in the directory `/var/lib/redis` (_which is a symbolic link to `/var/mail-state/lib-redis/` when [`ONE_DIR=1`](../environment.md#one_dir) and a volume is mounted to `/var/mail-state/`_). With the volume mount the snapshot will restore the Redis data across container restarts, and provide a way to keep backup.

Redis uses `/etc/redis/redis.conf` for configuration. We adjust this file when enabling the internal Redis service. If you have an external instance of Redis to use, the internal Redis service can be opt-out via setting the ENV  [`ENABLE_RSPAMD_REDIS=0`](../environment.md#enable_rspamd_redis) (_link also details required changes to the DMS rspamd config_).

### Web Interface

Rspamd provides a [web interface][rspamc-docs-web-interface], which contains statistics and data Rspamd collects. The interface is enabled by default and reachable on port 11334.

![Rspamd Web Interface](https://rspamd.com/img/webui.png)

[rspamc-docs-web-interface]: https://rspamd.com/webui/

### Modules

You can find a list of all Rspamd modules [on their website][modules].

#### Disabled By Default

DMS disables certain modules (clickhouse, elastic, neural, reputation, spamassassin, url_redirector, metric_exporter) by default. We believe these are not required in a standard setup, and they would otherwise needlessly use system resources.

#### Anti-Virus (ClamAV)

You can choose to enable ClamAV, and Rspamd will then use it to check for viruses. Just set the environment variable `ENABLE_CLAMAV=1`.

#### RBLs (Realtime Blacklists) / DNSBLs (DNS-based Blacklists)

The [RBL module](https://rspamd.com/doc/modules/rbl.html) is enabled by default. As a consequence, Rspamd will perform DNS lookups to a variety of blacklists. Whether an RBL or a DNSBL is queried depends on where the domain name was obtained: RBL servers are queried with IP addresses extracted from message headers, DNSBL server are queried with domains and IP addresses extracted from the message body \[[source][rbl-vs-dnsbl]\].

!!! danger "Rspamd and DNS Block Lists"

    When the RBL module is enabled, Rspamd will do a variety of DNS requests to (amongst other things) DNSBLs. There are a variety of issues involved when using DNSBLs. Rspamd will try to mitigate some of them by properly evaluating all return codes. This evaluation is a best effort though, so if the DNSBL operators change or add return codes, it may take a while for Rspamd to adjust as well.

    If you want to use DNSBLs, **try to use your own DNS resolver** and make sure it is set up correctly, i.e. it should be a non-public & **recursive** resolver. Otherwise, you might not be able ([see this Spamhaus post](https://www.spamhaus.org/faq/section/DNSBL%20Usage#365)) to make use of the block lists.

## Providing Custom Settings & Overriding Settings

### Manually

DMS brings sane default settings for Rspamd. They are located at `/etc/rspamd/local.d/` inside the container (or `target/rspamd/local.d/` in the repository). If you want to change these settings and / or provide your own settings, you can

1. place files at `/etc/rspamd/override.d/` which will override Rspamd settings and DMS settings
2. (re-)place files at `/etc/rspamd/local.d/` to override DMS settings and merge them with Rspamd settings

!!! warning "Clashing Overrides"

    Note that when also [using the `rspamd-commands` file](#with-the-help-of-a-custom-file), files in `override.d` may be overwritten in case you adjust them manually and with the help of the file.

### With the Help of a Custom File

DMS provides the ability to do simple adjustments to Rspamd modules with the help of a single file. Just place a file called `rspamd-modules.conf` into the [local config directory `docker-data/dms/config/`][docs-volumes-config]. If this file is present, DMS will evaluate it. The structure is _very_ simple. Each line in the file looks like this:

```txt
COMMAND ARGUMENT1 ARGUMENT2 ARGUMENT3
```

where `COMMAND` can be:

1. `disable-module`: disables the module with name `ARGUMENT1`
2. `enable-module`: explicitly enables the module with name `ARGUMENT1`
3. `set-option-for-module`: sets the value for option `ARGUMENT2` to `ARGUMENT3` inside module `ARGUMENT1`
4. `set-option-for-controller`: set the value of option `ARGUMENT1` to `ARGUMENT2` for the controller worker
5. `set-option-for-proxy`: set the value of option `ARGUMENT1` to `ARGUMENT2` for the proxy worker
6. `set-common-option`: set the option `ARGUMENT1` that [defines basic Rspamd behaviour][basic-options] to value `ARGUMENT2`
7. `add-line`: this will add the complete line after `ARGUMENT1` (with all characters) to the file `/etc/rspamd/override.d/<ARGUMENT1>`

!!! example "An Example Is [Shown Down Below](#adjusting-and-extending-the-very-basic-configuration)"

!!! note "File Names & Extensions"

    For command 1 - 3, we append the `.conf` suffix to the module name to get the correct file name automatically. For commands 4 - 6, the file name is fixed (you don't even need to provide it). For command 7, you will need to provide the whole file name (including the suffix) yourself!

You can also have comments (the line starts with `#`) and blank lines in `rspamd-modules.conf` - they are properly handled and not evaluated.

!!! tip "Adjusting Modules This Way"

    These simple commands are meant to give users the ability to _easily_ alter modules and their options. As a consequence, they are not powerful enough to enable multi-line adjustments. If you need to do something more complex, we advise to do that [manually](#manually)!

## Examples & Advanced Configuration

### A Very Basic Configuration

You want to start using Rspamd? Rspamd is disabled by default, so you need to set the following environment variables:

```cf
ENABLE_RSPAMD=1
ENABLE_OPENDKIM=0
ENABLE_OPENDMARC=0
ENABLE_AMAVIS=0
ENABLE_SPAMASSASSIN=0
```

This will enable Rspamd and disable services you don't need when using Rspamd. Note that with this setup, the default DKIM signing that DMS provides does not work (as it is disabled)! To solve this issue, look at [this subsection](#dkim-signing).

### Adjusting and Extending The Very Basic Configuration

Rspamd is running, but you want or need to adjust it?

1. Say you want to be able to easily look at the frontend Rspamd provides on port 11334 (default) without the need to enter a password (maybe because you already provide authorization and authentication). You will need to adjust the controller worker: create a file called `rspamd-modules.conf` and add the line `set-option-for-controller secure_ip "0.0.0.0/0"`. Place the file `rspamd-modules.conf` inside the directory on the host you mount to `/tmp/docker-mailserver/` inside the container (in our documentation, we use `docker-data/dms/config` on the host for this purpose). And you're done! Note: this disables authentication on the website - make sure you know what you're doing!
2. You additionally want to enable the auto-spam-learning for the Bayes module? No problem, just add another line to `rspamd-modules.conf` that looks like this: `set-option-for-module classifier-bayes autolearn true`.
3. But the chartable module gets on your nerves? Just disable it by adding another line: `disable-module chartable
`.

### DKIM Signing

There is a dedicated [section for setting up DKIM with Rspamd in our documentation][docs-dkim-with-rspamd].

[docs-dkim-with-rspamd]: ../best-practices/dkim_dmarc_spf.md#dkim

### _Abusix_ Integration

This subsection gives information about the integration of [Abusix], "a set of blocklists that work as an additional email security layer for your existing mail environment". The setup is straight-forward and well documented:

1. [Create an account](https://app.abusix.com/signup)
2. Retrieve your API key
3. Navigate to the ["Getting Started" documentation for Rspamd][abusix-rspamd-integration] and follow the steps described there
4. Make sure to change `<APIKEY>` to your private API key

We recommend mounting the files directly into the container, as they are rather big and not manageable with the [modules script](#with-the-help-of-a-custom-file). If mounted to the correct location, Rspamd will automatically pick them up.

While _Abusix_ can be integrated into Postfix, Postscreen and a multitude of other software, we recommend integrating _Abusix_ only into a single piece of software running in your mail server - everything else would be excessive and wasting queries. Moreover, we recommend the integration into suitable filtering software and not Postfix itself, as software like Postscreen or Rspamd can properly evaluate the return codes and other configuration.

[Abusix]: https://abusix.com/
[abusix-rspamd-integration]: https://docs.abusix.com/abusix-mail-intelligence/gbG8EcJ3x3fSUv8cMZLiwA/getting-started/dmw9dcwSGSNQiLTssFAnBW#rspamd

[//]: # (General Links)

[docs-volumes-config]: ../advanced/optional-config.md
[homepage]: https://rspamd.com/
[modules]: https://rspamd.com/doc/modules/
[proxy-self-scan-mode]: https://rspamd.com/doc/workers/rspamd_proxy.html#self-scan-mode
[dms-default-configuration]: https://github.com/docker-mailserver/docker-mailserver/tree/master/target/rspamd
[rbl-vs-dnsbl]: https://forum.eset.com/topic/25277-dnsbl-vs-rbl-mail-security/?do=findComment&comment=119818
[dkim-signing-module]: https://rspamd.com/doc/modules/dkim_signing.html
[basic-options]: https://rspamd.com/doc/configuration/options.html
