---
title: 'Advanced | Compression'
---

## Overview

Compression allows all messages to be compressed on save, and compressed messages to be read, regardless of the Algorithm chosen. Dovecot **zlib** plugin supports a variety of algorithms:

| Name | Library (algorithm) | Dovecot Support |
| ---- | ------------------- | --------------- |
| `bz2` | [libbzip2 (bzip2)](https://sourceware.org/bzip2/) | v2.0+ |
| `gz`  | [zlib (gzip)](https://www.zlib.net/) | v2.0+ |
| `deflate` | [zlib (gzip)](https://www.zlib.net/) | v2.0+ |
| `lz4` | [liblz4](https://www.lz4.org/) | v2.2.11+ |
| `zstd` | [Zstandard](https://facebook.github.io/zstd/) | v2.3.12+ |

Please be aware that compression increases the CPU usage of the container just a little. However, when dealing with large attachements, users may experience delays and the container CPU may spike.

### Zlib

The [dovecot-zlib](https://doc.dovecot.org/2.3/configuration_manual/zlib_plugin/) plugin can be used to read compressed mbox, maildir or dbox files. It can also be used to write (via IMAP, LDA and/or LMTP Server) compressed messages to dbox or Maildir mailboxes.

While compression can be memory intensive for large messages, you can configure the plugin to limit the amount of memory consumed by the workers. Using `zstd` seems to be the best and faster algorith to date.

#### Benchmarking

Source: [dovecot-mail_compress](https://github.com/dovecot/documentation/edit/main/docs/core/plugins/mail_compress.md)

* Compression of a real-world corpus of mails of various lengths, compositions, and types
* 128,788 messages
* Messages imported via [man,doveadm-import](https://doc.dovecot.org/main/core/man/doveadm-import.1.html) into a single [sdbox](https://doc.dovecot.org/main/core/config/mailbox_formats/dbox.html#single-dbox-sdbox) mailbox
  * Mailbox storage in tmpfs partition, so drive performance should be irrelevant
* Time is total clock time (real + sys) to compress the entire mailbox
* Size is the total size of the sdbox mail data directory ONLY
  * Dovecot indexes are not included in size

#### Results

| Algorithm | Size (GB) | Compression | Time (MM:SS) |
| --------- | --------- | ----------- | ------------ |
| None | 7.99 | 0% | 0:21 |
| `bz2` | 3.41 | 57% | 7:08 |
| `gz`  | 3.44 | 57% | 2:30 |
| `deflate` | 3.44 | 57% | 2:34 |
| `lz4` | 4.76 | 40% | 0:23 |
| `zstd` | 3.41 | 57% | 0:34 |

The clear winner is `zstd` but your results may vary.

#### Setup

1. To configure `zlib` as a dovecot plugin, create a file at `docker-data/dms/config/dovecot/12-compress.conf` and place the following in it:

    ```
    mail_plugins = $mail_plugins zlib

    # Enable these only if you want compression while saving:
    plugin {
      # zlib_save = gz
      # zlib_save_level = 1
      zlib_save = zstd
    }

    # Enable Zlib for imap
    protocol imap {
      mail_plugins = $mail_plugins zlib
    }

    # Enable Zlib for pop3
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


3. Update `compose.yaml` to load the previously created dovecot plugin config file:

    ```yaml
      services:
        mailserver:
          image: ghcr.io/docker-mailserver/docker-mailserver:latest
          container_name: mailserver
          hostname: mail.example.com
          env_file: mailserver.env
          ports:
            - "25:25"    # SMTP  (explicit TLS => STARTTLS)
            - "143:143"  # IMAP4 (explicit TLS => STARTTLS)
            - "465:465"  # ESMTP (implicit TLS)
            - "587:587"  # ESMTP (explicit TLS => STARTTLS)
            - "993:993"  # IMAP4 (implicit TLS)
          volumes:
            - /etc/localtime:/etc/localtime:ro
            - ./docker-data/dms/mail-data/:/var/mail/
            - ./docker-data/dms/mail-state/:/var/mail-state/
            - ./docker-data/dms/mail-logs/:/var/log/mail/
            - ./docker-data/dms/config/:/tmp/docker-mailserver/
    
            - ./docker-data/dms/config/dovecot/12-compress.conf:/etc/dovecot/conf.d/12-compress.conf:ro
          restart: always
          stop_grace_period: 1m
          # Uncomment if using `ENABLE_FAIL2BAN=1`:
          # cap_add:
            # - NET_ADMIN
    ```

4. Recreate containers:

    ```
    docker compose down
    docker compose up -d --force-recreate
    ```

### Debugging

#### Cached message size larger than expected
```
mailu dovecot: indexer-worker(user@mydomain.com)<1662><PLy3NgU3z2h8BgAAPDOPJQ:vWooFAY3z2h>: Error: Mailbox INBOX: UID=3: read(/var/mail/mydomain.com/user/cur/1758395999.M371909P1818.mx.mydomain.com,S=30343,W=30821:2,S) failed: Cached message size larger than expected (30343 > 16567, box=INBOX, UID=3) (read reason=mail stream)
mailu dovecot: indexer-worker(user@mydomain.com)<1662><PLy3NgU3z2h8BgAAPDOPJQ:vWooFAY3z2h>: Error: Mailbox INBOX: Deleting corrupted cache record uid=3: UID 3: Broken physical size in mailbox INBOX: read(/var/mail/mydomain.com/user/cur/1758395999.M371909P1818.mx.mydomain.com,S=30343,W=30821:2,S) failed: Cached message size larger than expected (30343 > 16567, box=INBOX, UID=3)
```

Common error after importing devocot mailboxes from another system where they are compressed, but you did not enable zlib yet.

Also could be caused by incorrect loading of the plugin: wrong path in `compose.yaml`, wrong order, syntax error in 12-compress.conf ...
