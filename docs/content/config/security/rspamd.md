---
title: 'Security | Rspamd'
---

## About

Rspamd is a ["fast, free and open-source spam filtering system"][rspamd-homepage]. DMS integrates Rspamd like any other service. We provide a very simple but easy to maintain setup of Rspamd.

If you want to have a look at the default configuration files for Rspamd that DMS packs, navigate to [`target/rspamd/` inside the repository][dms-default-configuration]. Please consult the [section "The Default Configuration"](#the-default-configuration) section down below for a written overview.

!!! note "AMD64 vs ARM64"

    We are currently doing a best-effort installation of Rspamd for ARM64 (from the Debian backports repository for Debian 11). The current version difference as of 23rd Apr 2023: AMD64 is at version 3.5 | ARM64 is at version 3.4.

[rspamd-homepage]: https://rspamd.com/
[dms-default-configuration]: https://github.com/docker-mailserver/docker-mailserver/tree/master/target/rspamd

## Related Environment Variables

The following environment variables are related to Rspamd:

1. [`ENABLE_RSPAMD`](../environment.md#enable_rspamd)
2. [`ENABLE_RSPAMD_REDIS`](../environment.md#enable_rspamd_redis)
3. [`RSPAMD_CHECK_AUTHENTICATED`](../environment.md#rspamd_check_authenticated)
4. [`RSPAMD_GREYLISTING`](../environment.md#rspamd_greylisting)
5. [`RSPAMD_HFILTER`](../environment.md#rspamd_hfilter)
6. [`RSPAMD_HFILTER_HOSTNAME_UNKNOWN_SCORE`](../environment.md#rspamd_hfilter_hostname_unknown_score)
7. [`RSPAMD_LEARN`](../environment.md#rspamd_learn)
8. [`MOVE_SPAM_TO_JUNK`](../environment.md#move_spam_to_junk)
9. [`MARK_SPAM_AS_READ`](../environment.md#mark_spam_as_read)

With these variables, you can enable Rspamd itself and you can enable / disable certain features related to Rspamd.

## The Default Configuration

### Mode of Operation

The proxy worker operates in [self-scan mode][rspamd-docs-proxy-self-scan-mode]. This simplifies the setup as we do not require a normal worker. You can easily change this though by [overriding the configuration by DMS](#providing-custom-settings-overriding-settings).

DMS does not set a default password for the controller worker. You may want to do that yourself. In setups where you already have an authentication provider in front of the Rspamd webpage, you may want to [set the `secure_ip ` option to `"0.0.0.0/0"` for the controller worker](#with-the-help-of-a-custom-file) to disable password authentication inside Rspamd completely.

[rspamd-docs-proxy-self-scan-mode]: https://rspamd.com/doc/workers/rspamd_proxy.html#self-scan-mode

### Persistence with Redis

When Rspamd is enabled, we implicitly also start an instance of Redis in the container. Redis is configured to persist it's data via RDB snapshots to disk in the directory `/var/lib/redis` (_which is a symbolic link to `/var/mail-state/lib-redis/` when [`ONE_DIR=1`](../environment.md#one_dir) and a volume is mounted to `/var/mail-state/`_). With the volume mount the snapshot will restore the Redis data across container restarts, and provide a way to keep backup.

Redis uses `/etc/redis/redis.conf` for configuration. We adjust this file when enabling the internal Redis service. If you have an external instance of Redis to use, the internal Redis service can be opt-out via setting the ENV  [`ENABLE_RSPAMD_REDIS=0`](../environment.md#enable_rspamd_redis) (_link also details required changes to the DMS rspamd config_).

### Web Interface

Rspamd provides a [web interface][rspamc-docs-web-interface], which contains statistics and data Rspamd collects. The interface is enabled by default and reachable on port 11334.

![Rspamd Web Interface](https://rspamd.com/img/webui.png)

[rspamc-docs-web-interface]: https://rspamd.com/webui/

### DNS

DMS does not supply custom values for DNS servers to Rspamd. If you need to use custom DNS servers, which could be required when using [DNS-based black/whitelists](#rbls-realtime-blacklists-dnsbls-dns-based-blacklists), you need to adjust [`options.inc`][rspamd-docs-basic-options] yourself.

!!! tip "Making DNS Servers Configurable"

    If you want to see an environment variable (like `RSPAMD_DNS_SERVERS`) to support custom DNS servers for Rspamd being added to DMS, please raise a feature request issue.

!!! danger

    While we do not provide values for custom DNS servers by default, we set `soft_reject_on_timeout = true;` by default. This setting will cause a soft reject if a task (presumably a DNS request) timeout takes place.

    This setting is enabled to not allow spam to proceed just because DNS requests did not succeed. It could deny legitimate e-mails to pass though too in case your DNS setup is incorrect or not functioning properly.

### Logs

You can find the Rspamd logs at `/var/log/mail/rspamd.log`, and the corresponding logs for [Redis](#persistence-with-redis), if it is enabled, at `/var/log/supervisor/rspamd-redis.log`. We recommend inspecting these logs (with `docker exec -it <CONTAINER NAME> cat /var/log/mail/rspamd.log`) in case Rspamd does not work as expected.

### Modules

You can find a list of all Rspamd modules [on their website][rspamd-docs-modules].

[rspamd-docs-modules]: https://rspamd.com/doc/modules/

#### Disabled By Default

DMS disables certain modules (clickhouse, elastic, neural, reputation, spamassassin, url_redirector, metric_exporter) by default. We believe these are not required in a standard setup, and they would otherwise needlessly use system resources.

#### Anti-Virus (ClamAV)

You can choose to enable ClamAV, and Rspamd will then use it to check for viruses. Just set the environment variable `ENABLE_CLAMAV=1`.

#### RBLs (Realtime Blacklists) / DNSBLs (DNS-based Blacklists)

The [RBL module](https://rspamd.com/doc/modules/rbl.html) is enabled by default. As a consequence, Rspamd will perform DNS lookups to a variety of blacklists. Whether an RBL or a DNSBL is queried depends on where the domain name was obtained: RBL servers are queried with IP addresses extracted from message headers, DNSBL server are queried with domains and IP addresses extracted from the message body \[[source][rbl-vs-dnsbl]\].

!!! danger "Rspamd and DNS Block Lists"

    When the RBL module is enabled, Rspamd will do a variety of DNS requests to (amongst other things) DNSBLs. There are a variety of issues involved when using DNSBLs. Rspamd will try to mitigate some of them by properly evaluating all return codes. This evaluation is a best effort though, so if the DNSBL operators change or add return codes, it may take a while for Rspamd to adjust as well.

    If you want to use DNSBLs, **try to use your own DNS resolver** and make sure it is set up correctly, i.e. it should be a non-public & **recursive** resolver. Otherwise, you might not be able ([see this Spamhaus post](https://www.spamhaus.org/faq/section/DNSBL%20Usage#365)) to make use of the block lists.

[rbl-vs-dnsbl]: https://forum.eset.com/topic/25277-dnsbl-vs-rbl-mail-security/?do=findComment&comment=119818

## Providing Custom Settings & Overriding Settings

DMS brings sane default settings for Rspamd. They are located at `/etc/rspamd/local.d/` inside the container (or `target/rspamd/local.d/` in the repository).

### Manually

!!! question "What is [`docker-data/dms/config/`][docs-dms-config-volume]?"

If you want to overwrite the default settings and / or provide your own settings, you can place files at `docker-data/dms/config/rspamd/override.d/` (a directory that is linked to `/etc/rspamd/override.d/`, if it exists) to override Rspamd and DMS default settings. This directory will not do a complete file override, but a [forced override of the specific settings in that file][rspamd-docs-override-dir].

!!! warning "Clashing Overrides"

    Note that when also [using the `rspamd-commands` file](#with-the-help-of-a-custom-file), files in `override.d` may be overwritten in case you adjust them manually and with the help of the file.

[rspamd-docs-override-dir]: https://www.rspamd.com/doc/faq.html#what-are-the-locald-and-overrided-directories
[docs-dms-config-volume]: ../../faq.md#what-about-the-docker-datadmsconfig-directory

### With the Help of a Custom File

DMS provides the ability to do simple adjustments to Rspamd modules with the help of a single file. Just place a file called `custom-commands.conf` into `docker-data/dms/config/rspamd/`. If this file is present, DMS will evaluate it. The structure is _very_ simple. Each line in the file looks like this:

```txt
COMMAND ARGUMENT1 ARGUMENT2 ARGUMENT3
```

where `COMMAND` can be:

1. `disable-module`: disables the module with name `ARGUMENT1`
2. `enable-module`: explicitly enables the module with name `ARGUMENT1`
3. `set-option-for-module`: sets the value for option `ARGUMENT2` to `ARGUMENT3` inside module `ARGUMENT1`
4. `set-option-for-controller`: set the value of option `ARGUMENT1` to `ARGUMENT2` for the controller worker
5. `set-option-for-proxy`: set the value of option `ARGUMENT1` to `ARGUMENT2` for the proxy worker
6. `set-common-option`: set the option `ARGUMENT1` that [defines basic Rspamd behaviour][rspamd-docs-basic-options] to value `ARGUMENT2`
7. `add-line`: this will add the complete line after `ARGUMENT1` (with all characters) to the file `/etc/rspamd/override.d/<ARGUMENT1>`

!!! example "An Example Is [Shown Down Below](#adjusting-and-extending-the-very-basic-configuration)"

!!! note "File Names & Extensions"

    For command 1 - 3, we append the `.conf` suffix to the module name to get the correct file name automatically. For commands 4 - 6, the file name is fixed (you don't even need to provide it). For command 7, you will need to provide the whole file name (including the suffix) yourself!

You can also have comments (the line starts with `#`) and blank lines in `custom-commands.conf` - they are properly handled and not evaluated.

!!! tip "Adjusting Modules This Way"

    These simple commands are meant to give users the ability to _easily_ alter modules and their options. As a consequence, they are not powerful enough to enable multi-line adjustments. If you need to do something more complex, we advise to do that [manually](#manually)!

[rspamd-docs-basic-options]: https://rspamd.com/doc/configuration/options.html

## Examples & Advanced Configuration

### A Very Basic Configuration

You want to start using Rspamd? Rspamd is disabled by default, so you need to set the following environment variables:

```cf
ENABLE_RSPAMD=1
ENABLE_OPENDKIM=0
ENABLE_OPENDMARC=0
ENABLE_POLICYD_SPF=0
ENABLE_AMAVIS=0
ENABLE_SPAMASSASSIN=0
```

This will enable Rspamd and disable services you don't need when using Rspamd.

### Adjusting and Extending The Very Basic Configuration

Rspamd is running, but you want or need to adjust it? First, create a file named `custom-commands.conf` under `docker-data/dms/config/rspamd` (which translates to `/tmp/docker-mailserver/rspamd/` inside the container). Then add you changes:

1. Say you want to be able to easily look at the frontend Rspamd provides on port 11334 (default) without the need to enter a password (maybe because you already provide authorization and authentication). You will need to adjust the controller worker: `set-option-for-controller secure_ip "0.0.0.0/0"`.
2. You additionally want to enable the auto-spam-learning for the Bayes module? No problem: `set-option-for-module classifier-bayes autolearn true`.
3. But the chartable module gets on your nerves? Easy: `disable-module chartable`.

??? example "What Does the Result Look Like?"
    Here is what the file looks like in the end:

    ```bash
    # See 1.
    # ATTENTION: this disables authentication on the website - make sure you know what you're doing!
    set-option-for-controller secure_ip "0.0.0.0/0"

    # See 2.
    set-option-for-module classifier-bayes autolearn true

    # See 3.
    disable-module chartable
    ```

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
