---
title: 'Security | Rspamd'
---

!!! warning "Implementation of Rspamd into DMS is WIP!"

## About

Rspamd is a "fast, free and open-source spam filtering system". It offers high performance as it is written in C. Visit [their homepage][homepage] for more details.

## Integration & Configuration

We provide a very simple but easy to maintain setup of RSpamd. The proxy worker operates in [self-scan mode][proxy-self-scan-mode]. This simplifies the setup as we do not require a normal worker. You can easily change this though by [overriding the configuration by DMS](#providing-overriding-settings).

### Providing & Overriding Settings

DMS brings sane default settings for Rspamd. They are located at `/etc/rspamd/local.d/` inside the container (or `target/rspamd/local.d/` in the repository). If you want to change these settings and / or provide your own settings, you can

1. place files at `/etc/rspamd/override.d/` which will override Rspamd settings and DMS settings
2. (re-)place files at `/etc/rspamd/local.d/` to override DMS settings and merge them with Rspamd settings

You can find a list of all Rspamd modules [on their website][modules].

### DMS' Defaults

You can choose to enable ClamAV, and Rspamd will then use it to check for viruses. Just set the environment variable `ENABLE_CLAMAV=1`.

DMS disables certain modules (clickhouse, elastic, greylist, neural, reputation, spamassassin, url_redirector, metric_exporter) by default. We believe these are not required in a standard setup, and needlessly use resources. You can re-activate them by replacing `/etc/rspamd/local.d/<MODULE>.conf` or overriding DMS' default with `/etc/rspamd/override.d/<MODULE>.conf`.

DMS does not set a default password for the controller worker. You may want to do that yourself. In setup where you already have an authentication provider in front of the Rspamd webpage, you may add `secure_ip = "0.0.0.0/0";` to `worker-controller.inc` to disable password authentication inside Rspamd completely.

## Missing in DMS' Current Implementation

We currently lack easy integration for DKIM signing outgoing mails. We use OpenDKIM though which works just as well. If you want to use Rspamd for DKIM signing, you need to provide all settings yourself and probably also set the environment `ENABLE_OPENDKIM=0`. Rspamd will still check for valid DKIM signatures for incoming mail by default.

[homepage]: https://rspamd.com/
[modules]: https://rspamd.com/doc/modules/
[proxy-self-scan-mode]: https://rspamd.com/doc/workers/rspamd_proxy.html#self-scan-mode
