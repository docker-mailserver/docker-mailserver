---
title: 'Advanced | Full-Text Search'
---

## Overview

Full-text search allows all messages to be indexed, so that mail clients can quickly and efficiently search messages by their full text content.

The [dovecot-solr Plugin](https://wiki2.dovecot.org/Plugins/FTS/Solr) is used in conjunction with [Apache Solr](https://lucene.apache.org/solr/) running in a separate container. This is quite straightforward to setup using the following instructions.

## Setup Steps

1. `docker-compose.yml`:

    ```yaml
      solr:
        image: lmmdock/dovecot-solr:latest
        volumes:
          - solr-dovecot:/opt/solr/server/solr/dovecot
        restart: always

      mailserver:
        image: mailserver/docker-mailserver:latest
        ...
        volumes:
          ...
          - ./etc/dovecot/conf.d/10-plugin.conf:/etc/dovecot/conf.d/10-plugin.conf:ro
        ...

    volumes:
      solr-dovecot:
        driver: local
    ```

2. `etc/dovecot/conf.d/10-plugin.conf`:

    ```conf
    mail_plugins = $mail_plugins fts fts_solr

    plugin {
      fts = solr
      fts_autoindex = yes
      fts_solr = url=http://solr:8983/solr/dovecot/ 
    }
    ```

3. Start the solr container: `docker-compose up -d --remove-orphans solr`

4. Restart the mailserver container: `docker-compose restart mailserver`

5. Flag all user mailbox FTS indexes as invalid, so they are rescanned on demand when they are next searched: `docker-compose exec mailserver doveadm fts rescan -A`


## Further Discussion

See [#905][github-issue-905]

[github-issue-905]: https://github.com/docker-mailserver/docker-mailserver/issues/905
