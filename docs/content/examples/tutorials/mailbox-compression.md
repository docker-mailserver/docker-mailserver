---
title: 'Tutorials | Mailbox Compression'
---

## Overview

Compression allows all messages compressed or not to be READ, and/or compressed on save, regardless of the Algorithm chosen for write. Dovecot message compression plugin supports a variety of algorithms, please review them and the options available at:

* Dovecot 2.3- / DMS 15-: [dovecot-zlib](https://doc.dovecot.org/2.3/configuration_manual/zlib_plugin/)
* Dovecot 2.4+ / DMS 16+: [mail-compress](https://doc.dovecot.org/2.4.1/core/plugins/mail_compress.html)

Using `zstd` method seems to be the best and faster algorithm to date, according to a recent [mail_compress-benchmark](https://github.com/dovecot/documentation/edit/main/docs/core/plugins/mail_compress.md).

While compression can be memory intensive for large messages, you can configure the plugin to limit the amount of memory consumed by the workers. Examples shown mention the `vsz_limit` setting to limit to 1GB RAM for instance.

## Setup

### Dovecot < 2.4 / DMS < 16

To configure  as a dovecot plugin, create a file at `docker-data/dms/config/dovecot/12-compress-2.3.conf` and place the following in it:

```
mail_plugins = $mail_plugins zlib

# Enable WRITE compression on saving messages:
plugin {
  # zlib_save = gz
  # zlib_save_level = 1
  zlib_save = zstd
}

# Enable READ compression for IMAP:
# Enable Zlib for imap
protocol imap {
  mail_plugins = $mail_plugins zlib
}

# Enable READ compression for POP3:
protocol pop3 {
  mail_plugins = $mail_plugins zlib
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

From Dovecot 2.4, the compression plugin name and setup have changed: [mail-compress](https://doc.dovecot.org/2.4.1/core/plugins/mail_compress.html). Create a file at `docker-data/dms/config/dovecot/12-compress.conf` and place the following in it:

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

Update `compose.yaml` to load the dovecot plugin compression plugin file:

```yaml
  services:
    mailserver:
      ...
      volumes:
      ...
        # for DMS 15-
        - ./docker-data/dms/config/dovecot/12-compress-2.3.conf:/etc/dovecot/conf.d/12-compress-2.3.conf:ro
        # for DMS 16+
        - ./docker-data/dms/config/dovecot/12-compress-2.4.conf:/etc/dovecot/conf.d/12-compress-2.4.conf:ro
```

Finally, restart compose:

```
docker compose up -d --force-recreate
```

### Verify your configuration

After restarting the DMS container, execute those commands to check that the compresison plugin is indeed loaded properly (replace `dms` by the name of your DMS container):

```
docker exec -it dms doveconf -f protocol=lmtp mail_plugins
  # mail_plugins =  quota fts fts_xapian zlib sieve

docker exec -it dms doveconf -f protocol=imap mail_plugins
  # mail_plugins =  quota fts fts_xapian zlib zlib imap_quota imap_sieve

docker exec -it dms doveconf -f protocol=pop3 mail_plugins
  # mail_plugins =  quota fts fts_xapian zlib zlib
```

The output above show that zlib is activated for lmtp/imap/pop3 with DMS 15-/Dovecot 2.3-. This output will change a little with Dovecot 2.4+ as the compression plugin name has changed.

## Debugging

### Cached message size larger than expected
```
dms dovecot: indexer-worker(user@example.com)<1662><PLy3NgU3z2h8BgAAPDOPJQ:vWooFAY3z2h>: Error: Mailbox INBOX: UID=3: read(/var/mail/example.com/user/cur/1758395999.M371909P1818.mx.example.com,S=30343,W=30821:2,S) failed: Cached message size larger than expected (30343 > 16567, box=INBOX, UID=3) (read reason=mail stream)
dms dovecot: indexer-worker(user@example.com)<1662><PLy3NgU3z2h8BgAAPDOPJQ:vWooFAY3z2h>: Error: Mailbox INBOX: Deleting corrupted cache record uid=3: UID 3: Broken physical size in mailbox INBOX: read(/var/mail/example.com/user/cur/1758395999.M371909P1818.mx.example.com,S=30343,W=30821:2,S) failed: Cached message size larger than expected (30343 > 16567, box=INBOX, UID=3)
```

This is a common error after importing dovecot mailboxes from another system that were already compressed, but you did not enable zlib yet and dovecot is failing to read the messages.

Also could be caused by incorrect loading of the plugin: wrong path in `compose.yaml`, wrong order, syntax error in `12-compress.conf` ...
