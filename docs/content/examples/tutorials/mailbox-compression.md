---
title: 'Tutorials | Mailbox Compression'
---

## Overview

!!! warning "This is a community contributed guide"

    This content is entirely community supported. If you find errors, please open an issue and provide a PR.

Dovecot provides a plugin for _mailbox compression_. This plugin enables support to read messages from a mailbox that have been stored in a compressed format, as well as to write new incoming messages into a compressed format for storage.

Configuration differs by Dovecot version, which is dependent upon your DMS version:

- Dovecot 2.3 (DMS <=15): [`zlib`][dovecot::plugin::compression-2.3]
- Dovecot 2.4 (DMS >=16): [`mail-compress`][dovecot::plugin::compression-2.4]

!!! tip "Compression Algorithm"

    The plugin supports a variety of compression algorithms (see [this May 2025 benchmark][dovecot::plugin::compression-benchmark]), you'll likely want to choose `zstd`.

!!! info "Raising the memory limit to avoid errors"

    The memory requirements to support this plugin (depending on usage) may exceed the [default configured process memory limit][dovecot::config::default-vsz-limit] (_`default_vsz_limit`, 256 MiB_), or if configured a [service specific memory limit](https://doc.dovecot.org/2.4.1/core/config/service.html#service_vsz_limit). Examples shown mention the `vsz_limit` setting to limit to 1GB RAM for instance.

[dovecot::plugin::compression-2.3]: https://doc.dovecot.org/2.3/configuration_manual/zlib_plugin
[dovecot::plugin::compression-2.4]: https://doc.dovecot.org/2.4.1/core/plugins/mail_compress.html
[dovecot::plugin::compression-benchmark]: https://github.com/dovecot/documentation/blob/main/docs/core/plugins/mail_compress.md#benchmarking
[dovecot::config::default-vsz-limit]: https://doc.dovecot.org/2.4.1/core/summaries/settings.html#default_vsz_limit
[dovecot::config::service-vsz-limit]: https://doc.dovecot.org/2.4.1/core/config/service.html#service_vsz_limit

## Setup

### Dovecot < 2.4 / DMS < 16

To configure as a dovecot plugin, create a file at `docker-data/dms/config/dovecot/12-compress.conf` and place the following in it:

```
# Enable to support reading compressed messages:
mail_plugins = $mail_plugins zlib

# Enable compression with `zstd` when storing new messages
# (requires the `zlib` plugin enabled in `mail_plugins`):
plugin {
  zlib_save = zstd
}

# Increase memory allowed for imap as it costs more to read compressed files
service imap {
  vsz_limit = 1GB
}
```

Adjust the settings to tune for your desired memory limits and CPU usage.

The following compression levels are supported for `zlib_save_level`:

| Name   |   Minimum          |   Default | Maximum |
|--------|--------------------|-----------|-------- |
| `bz2`  | 1                  | 9         | 9       |
| `gz`   | 0 (no compression) | 6         | 9       |
| `lz4`  | 1                  | 1         | 9       |
| `zstd` | 1                  | 3         | 22      |

### Dovecot 2.4+ / DMS 16+

To configure as a dovecot plugin, create a file at `docker-data/dms/config/dovecot/12-compress.conf` and place the following in it:

```
# Enable compression plugin globally for reading/writing:
mail_plugins {
  mail_compress = yes
}

# Enable WRITE compression on saving messages:
mail_compress_write_method = zstd

# Increase memory allowed for imap as it costs more to read compressed files
service imap {
  vsz_limit = 1GB
}
```

Adjust the settings to tune for your desired memory limits and CPU usage.

The following compression levels are supported, and compression level are now controlled by one keyword per method:

| mail_compress_write_method |        Dovecot 2.4+          |       Minimum      |   Default | Maximum |
|----------------------------|------------------------------|--------------------|-----------|-------- |
| `bz2`                      | compress_bz2_block_size_100k | 1                  | 9         | 9       |
| `gz`                       | compress_gz_level            | 0 (no compression) | 6         | 9       |
| `deflate`                  | compress_deflate_level       | 0 (no compression) | 6         | 9       |
| `lz4`                      | ?                            | 1                  | 1         | 9       |
| `zstd`                     | compress_zstd_level          | 1                  | 3         | 22      |


### Include compression plugin in compose

In your `compose.yaml`, add a volume bind mount for the Dovecot plugin config to the container location `/etc/dovecot/conf.d/` (_the main Dovecot config `/etc/dovecot/dovecot.conf` will load all configs from that directory_).

```yaml
services:
  mailserver:
    volumes:
      - ./docker-data/dms/config/dovecot/12-compress.conf:/etc/dovecot/conf.d/12-compress.conf:ro
```

Ensure the new config is applied correctly by restarting DMS with `docker compose up -d --force-recreate`.

### Verify your configuration

After restarting the DMS container, check that the compression plugin was loaded properly:

```console
$ docker compose exec mailserver bash

$ doveconf -f protocol=lmtp mail_plugins
mail_plugins =  quota zlib sieve

$ doveconf -f protocol=imap mail_plugins
mail_plugins =  quota zlib imap_quota imap_sieve

$ doveconf -f protocol=pop3 mail_plugins
mail_plugins =  quota zlib
```

The output above show that compression plugin (`zlib` for Dovecot 2.3) is activated for the protocols queried (LMTP, IMAP, POP3). This output will change a little with Dovecot 2.4+ as the compression plugin name has changed.

## Troubleshooting

### Cached message size larger than expected

> ```
> dms dovecot: indexer-worker(john.doe@example.com)<1662><PLy3NgU3z2h8BgAAPDOPJQ:vWooFAY3z2h>: Error: Mailbox INBOX: UID=3: read(/var/mail/example.com/john.doe/cur/1758395999.M371909P1818.mail.example.com,S=30343,W=30821:2,S) failed: Cached message size larger than expected (30343 > 16567, box=INBOX, UID=3) (read reason=mail stream)
> 
> dms dovecot: indexer-worker(john.doe@example.com)<1662><PLy3NgU3z2h8BgAAPDOPJQ:vWooFAY3z2h>: Error: Mailbox INBOX: Deleting corrupted cache record uid=3: UID 3: Broken physical size in mailbox INBOX: read(/var/mail/example.com/john.doe/cur/1758395999.M371909P1818.mail.example.com,S=30343,W=30821:2,S) failed: Cached message size larger than expected (30343 > 16567, box=INBOX, UID=3)
> ```

This can occur from importing mail from Dovecot mailboxes from another system that were already compressed, but you haven't yet enabled the Dovecot plugin (_which is required to read them_).
