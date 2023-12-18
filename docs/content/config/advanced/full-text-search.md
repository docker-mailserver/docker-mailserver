---
title: 'Advanced | Full-Text Search'
---

## Overview

Full-text search allows all messages to be indexed, so that mail clients can quickly and efficiently search messages by their full text content. Dovecot supports a variety of community supported [FTS indexing backends](https://doc.dovecot.org/configuration_manual/fts/).

DMS comes pre-installed with two plugins that can be enabled with a dovecot config file.

Please be aware that indexing consumes memory and takes up additional disk space.

### Xapian

The [dovecot-fts-xapian](https://github.com/grosjo/fts-xapian) plugin makes use of [Xapian](https://xapian.org/). Xapian enables embedding an FTS engine without the need for additional backends.

The indexes will be stored as a subfolder named `xapian-indexes` inside your local `mail-data` folder (_`/var/mail` internally_). With the default settings, 10GB of email data may generate around 4GB of indexed data.

While indexing is memory intensive, you can configure the plugin to limit the amount of memory consumed by the index workers. With Xapian being small and fast, this plugin is a good choice for low memory environments (2GB) as compared to Solr.

#### Setup

1. To configure `fts-xapian` as a dovecot plugin, create a file at `docker-data/dms/config/dovecot/fts-xapian-plugin.conf` and place the following in it:

    ```
    mail_plugins = $mail_plugins fts fts_xapian

    plugin {
        fts = xapian
        fts_xapian = partial=3 full=20 verbose=0

        fts_autoindex = yes
        fts_enforced = yes

        # disable indexing of folders
        # fts_autoindex_exclude = \Trash

        # Index attachements
        # fts_decoder = decode2text
    }

    service indexer-worker {
        # limit size of indexer-worker RAM usage, ex: 512MB, 1GB, 2GB
        vsz_limit = 1GB
    }

    # service decode2text {
    #     executable = script /usr/libexec/dovecot/decode2text.sh
    #     user = dovecot
    #     unix_listener decode2text {
    #         mode = 0666
    #     }
    # }
    ```

    adjust the settings to tune for your desired memory limits, exclude folders and enable searching text inside of attachments

2. Update `compose.yaml` to load the previously created dovecot plugin config file:

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
            - ./docker-data/dms/mail-data/:/var/mail/
            - ./docker-data/dms/mail-state/:/var/mail-state/
            - ./docker-data/dms/mail-logs/:/var/log/mail/
            - ./docker-data/dms/config/:/tmp/docker-mailserver/
            - ./docker-data/dms/config/dovecot/fts-xapian-plugin.conf:/etc/dovecot/conf.d/10-plugin.conf:ro
            - /etc/localtime:/etc/localtime:ro
          restart: always
          stop_grace_period: 1m
          cap_add:
            - NET_ADMIN
    ```

3. Recreate containers:

    ```
    docker compose down
    docker compose up -d
    ```

4. Initialize indexing on all users for all mail:

    ```
    docker compose exec mailserver doveadm index -A -q \*
    ```

5. Run the following command in a daily cron job:

    ```
    docker compose exec mailserver doveadm fts optimize -A
    ```
    Or like the [Spamassassin example][docs-faq-sa-learn-cron] shows, you can instead use `cron` from within DMS to avoid potential errors if the mail server is not running:

??? example

    Create a _system_ cron file:

    ```sh
    # in the compose.yaml root directory
    mkdir -p ./docker-data/dms/cron # if you didn't have this folder before
    touch ./docker-data/dms/cron/fts_xapian
    chown root:root ./docker-data/dms/cron/fts_xapian
    chmod 0644 ./docker-data/dms/cron/fts_xapian
    ```

    Edit the system cron file `nano ./docker-data/dms/cron/fts_xapian`, and set an appropriate configuration:

    ```conf
    # Adding `MAILTO=""` prevents cron emailing notifications of the task outcome each run
    MAILTO=""
    #
    # m h dom mon dow user command
    #
    # Everyday 4:00AM, optimize index files
    0  4 * * * root  doveadm fts optimize -A
    ```

    Then with `compose.yaml`:

    ```yaml
    services:
      mailserver:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        volumes:
          - ./docker-data/dms/cron/fts_xapian:/etc/cron.d/fts_xapian
    ```


### Solr

The [dovecot-solr Plugin](https://wiki2.dovecot.org/Plugins/FTS/Solr) is used in conjunction with [Apache Solr](https://lucene.apache.org/solr/) running in a separate container. This is quite straightforward to setup using the following instructions.

Solr is a mature and fast indexing backend that runs on the JVM. The indexes are relatively compact compared to the size of your total email.

However, Solr also requires a fair bit of RAM. While Solr is [highly tuneable](https://solr.apache.org/guide/7_0/query-settings-in-solrconfig.html), it may require a bit of testing to get it right.

#### Setup

1. `compose.yaml`:

    ```yaml
      solr:
        image: lmmdock/dovecot-solr:latest
        volumes:
          - ./docker-data/dms/config/dovecot/solr-dovecot:/opt/solr/server/solr/dovecot
        restart: always

      mailserver:
        depends_on:
          - solr
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        ...
        volumes:
          ...
          - ./docker-data/dms/config/dovecot/10-plugin.conf:/etc/dovecot/conf.d/10-plugin.conf:ro
        ...
    ```

2. `./docker-data/dms/config/dovecot/10-plugin.conf`:

    ```conf
    mail_plugins = $mail_plugins fts fts_solr

    plugin {
      fts = solr
      fts_autoindex = yes
      fts_solr = url=http://solr:8983/solr/dovecot/
    }
    ```

3. Recreate containers: `docker compose down ; docker compose up -d`

4. Flag all user mailbox FTS indexes as invalid, so they are rescanned on demand when they are next searched: `docker compose exec mailserver doveadm fts rescan -A`

#### Further Discussion

See [#905](https://github.com/docker-mailserver/docker-mailserver/issues/905)

[docs-faq-sa-learn-cron]: ../../faq.md#how-can-i-make-spamassassin-better-recognize-spam
