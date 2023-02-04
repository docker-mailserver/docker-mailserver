---
title: 'Security | Rspamd'
---

!!! warning "The Current State of Rspamd's Integration Into DMS"

    Recent pull requests have stabilized Rspamd's integration to a point where we encourage users to test the feature. We are confident that there are no major bugs in our code anymore that make using Rspamd infeasible. Please do note that there may still be breaking changes (made to the default configuration of Rspamd) as integration is still work in progress!

    We expect to stabilize this feature with version `v12.1.0`.

## About

Rspamd is a "fast, free and open-source spam filtering system". It offers high performance as it is written in C. Visit [their homepage][homepage] for more details.

## Integration & Configuration

We provide a very simple but easy to maintain setup of RSpamd. The proxy worker operates in [self-scan mode][proxy-self-scan-mode]. This simplifies the setup as we do not require a normal worker. You can easily change this though by [overriding the configuration by DMS](#providing-overriding-settings). If you want to have a look at the default configuration for Rspamd that DMS packs, navigate to [`target/rspamd/` inside the repository][dms-default-configuration].

### Providing & Overriding Settings

You can find a list of all Rspamd modules [on their website][modules].

#### Manually

DMS brings sane default settings for Rspamd. They are located at `/etc/rspamd/local.d/` inside the container (or `target/rspamd/local.d/` in the repository). If you want to change these settings and / or provide your own settings, you can

1. place files at `/etc/rspamd/override.d/` which will override Rspamd settings and DMS settings; **note** that when also [using DMS' `rspamd-commands` file](#with-the-help-of-a-custom-file), files in `override.d` may be overwritten in case you adjust them manually and with the help of the file
2. (re-)place files at `/etc/rspamd/local.d/` to override DMS settings and merge them with Rspamd settings

#### With the Help of a Custom File

DMS provides the ability to do simple adjustments to Rspamd modules with the help of a file you can mount to `docker-data/dms/config/rspamd-commands`. If this file is present, DMS will evaluate it. The structure is _very_ simple. Each line in the file looks like this:

```txt
COMMAND MODULE ARGUMENT1 ARGUMENT2
```

where `COMMAND` can be:

1. `disable-module`: this will disable the module with name `MODULE` (if `ARGUMENT1` is set, it will be used inside the link to the Rspamd documentation for this module in the module file in case the name in the URL is different from the module name; if unset, the name of the module is used)
2. `enable-module`: this will explicitly enabled the module with name `MODULE` (if `ARGUMENT1` is set, it will be used inside the link to the Rspamd documentation for this module in the module file in case the name in the URL is different from the module name; if unset, the name of the module is used)
3. `set-option-for-module`: this will set the value for option `ARGUMENT1` inside the module `MODULE` to `ARGUMENT2`
4. `add-line-to-module`: this will add the line `ARGUMENT1 ARGUMENT2` to the module `MODULE`

You can also have comments (the line starts with `#`) and blank lines in `rspamd-commands` - they are properly handled and not evaluated.

!!! tip "Adjusting Modules This Way"

    These simple commands are meant to give users the ability to _easily_ alter modules and their options. As a consequence, they are not powerful enough to enable multi-line adjustments. If you need to do something more complex, we advise to do that [manually](#manually)!

### DMS' Defaults

You can choose to enable ClamAV, and Rspamd will then use it to check for viruses. Just set the environment variable `ENABLE_CLAMAV=1`.

DMS disables certain modules (clickhouse, elastic, greylist, neural, reputation, spamassassin, url_redirector, metric_exporter) by default. We believe these are not required in a standard setup, and needlessly use resources. You can re-activate them by replacing `/etc/rspamd/local.d/<MODULE>.conf` or overriding DMS' default with `/etc/rspamd/override.d/<MODULE>.conf`.

DMS does not set a default password for the controller worker. You may want to do that yourself. In setup where you already have an authentication provider in front of the Rspamd webpage, you may add `secure_ip = "0.0.0.0/0";` to `worker-controller.inc` to disable password authentication inside Rspamd completely.

## Missing in DMS' Current Implementation

We currently lack easy integration for DKIM signing outgoing mails. We use OpenDKIM though which works just as well. If you want to use Rspamd for DKIM signing, you need to provide all settings yourself and probably also set the environment `ENABLE_OPENDKIM=0`. Rspamd will still check for valid DKIM signatures for incoming mail by default.

[homepage]: https://rspamd.com/
[modules]: https://rspamd.com/doc/modules/
[proxy-self-scan-mode]: https://rspamd.com/doc/workers/rspamd_proxy.html#self-scan-mode
[dms-default-configuration]: https://github.com/docker-mailserver/docker-mailserver/tree/master/target/rspamd
