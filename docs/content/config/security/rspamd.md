---
title: 'Security | Rspamd'
---

!!! warning "The current state of Rspamd integration into DMS"

    Recent pull requests have stabilized integration of Rspamd to a point that we encourage users to test the feature. We are confident that there are no major bugs in our integration that make using Rspamd infeasible. Please note that there may still be (breaking) changes ahead as integration is still work in progress!

    We expect to stabilize this feature with version `v12.1.0`.

## About

Rspamd is a ["fast, free and open-source spam filtering system"][homepage]. DMS integrates Rspamd like any other service. You will need to enable Rspamd (via `ENABLE_RSPAMD=1`) manually as it is disabled by default.

We provide a very simple but easy to maintain setup of Rspamd. If you want to have a look at the default configuration files for Rspamd that DMS packs, navigate to [`target/rspamd/` inside the repository][dms-default-configuration]. Please consult the [section "The Default Configuration"](#the-default-configuration) section down below for a written overview.

If you want to adjust Rspamd's configuration, have a look at the ["Providing Custom Settings & Overriding Settings" section](#providing-custom-settings-overriding-settings) down below.

## The Default Configuration

### Mode of Operation

The proxy worker operates in [self-scan mode][proxy-self-scan-mode]. This simplifies the setup as we do not require a normal worker. You can easily change this though by [overriding the configuration by DMS](#providing-custom-settings-overriding-settings).

DMS does not set a default password for the controller worker. You may want to do that yourself. In setup where you already have an authentication provider in front of the Rspamd webpage, you may add `secure_ip = "0.0.0.0/0";` to `worker-controller.inc` to disable password authentication inside Rspamd completely.

### Modules

You can find a list of all Rspamd modules [on their website][modules].

#### Disabled By Default

DMS disables certain modules (clickhouse, elastic, greylist, neural, reputation, spamassassin, url_redirector, metric_exporter) by default. We believe these are not required in a standard setup, and they would otherwise needlessly use system resources.

#### Anti-Virus (ClamAV)

You can choose to enable ClamAV, and Rspamd will then use it to check for viruses. Just set the environment variable `ENABLE_CLAMAV=1`.

### Missing in the Current Implementation

We currently lack easy integration for DKIM signing outgoing mails. We use OpenDKIM though which works just as well. If you want to use Rspamd for DKIM signing, you need to provide all settings yourself and probably also set the environment variable `ENABLE_OPENDKIM=0`. Rspamd will still check for valid DKIM signatures for incoming mail by default.

## Providing Custom Settings & Overriding Settings

### Manually

DMS brings sane default settings for Rspamd. They are located at `/etc/rspamd/local.d/` inside the container (or `target/rspamd/local.d/` in the repository). If you want to change these settings and / or provide your own settings, you can

1. place files at `/etc/rspamd/override.d/` which will override Rspamd settings and DMS settings
2. (re-)place files at `/etc/rspamd/local.d/` to override DMS settings and merge them with Rspamd settings

!!! warning "Clashing Overrides"

    Note that when also [using the `rspamd-commands` file](#with-the-help-of-a-custom-file), files in `override.d` may be overwritten in case you adjust them manually and with the help of the file.

### With the Help of a Custom File

DMS provides the ability to do simple adjustments to Rspamd modules with the help of a single file. Just place a file called `rspamd-modules.conf` into the directory `docker-data/dms/config/` (which translates to `/tmp/docker-mailserver/` in the container). If this file is present, DMS will evaluate it. The structure is _very_ simple. Each line in the file looks like this:

```txt
COMMAND ARGUMENT1 ARGUMENT2 ARGUMENT3
```

where `COMMAND` can be:

1. `disable-module`: disables the module with name `ARGUMENT1`
2. `enable-module`: explicitly enables the module with name `ARGUMENT1`
3. `set-option-for-module`: sets the value for option `ARGUMENT2` to `ARGUMENT3` inside module `ARGUMENT1`
4. `set-option-for-controller`: set the value of option `ARGUMENT1` to `ARGUMENT2` for the controller worker
5. `set-option-for-proxy`: set the value of option `ARGUMENT1` to `ARGUMENT2` for the proxy worker
6. `add-line`: this will add the complete line after `ARGUMENT1` (with all characters) to the file `/etc/rspamd/override.d/<ARGUMENT1>`

!!! note "File Names & Extensions"

    For command 1-3, we append the `.conf` suffix to the module name to get the correct file name automatically. For commands 4 & 5, the file name is fixed (you don't even need to provide it). For command 6, you will need to provide the whole file name (including the suffix) yourself!

You can also have comments (the line starts with `#`) and blank lines in `rspamd-modules.conf` - they are properly handled and not evaluated.

!!! tip "Adjusting Modules This Way"

    These simple commands are meant to give users the ability to _easily_ alter modules and their options. As a consequence, they are not powerful enough to enable multi-line adjustments. If you need to do something more complex, we advise to do that [manually](#manually)!

[homepage]: https://rspamd.com/
[modules]: https://rspamd.com/doc/modules/
[proxy-self-scan-mode]: https://rspamd.com/doc/workers/rspamd_proxy.html#self-scan-mode
[dms-default-configuration]: https://github.com/docker-mailserver/docker-mailserver/tree/master/target/rspamd
