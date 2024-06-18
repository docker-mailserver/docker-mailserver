# Dovecot Full Text Search (FTS) using the Solr Backend

Dovecot supports several FTS backends for providing fast and efficient full text searching of e-mails directly from the IMAP server.

As the size of your mail storage grows, the benefits of FTS is especially notable:

- Without FTS, Dovecot would perform a search query by checking each individual email stored for a match, and then repeat this process again from scratch for the exact same query in future.
- Some mail clients (_like Thunderbird_) may provide their own indexing and search features when all mail to search is stored locally, otherwise Dovecot needs to handle the search query (_for example webmail and mobile clients, like Gmail_).
- FTS indexes each mail into a database for querying instead, where it can skip the cost of inspecting irrelevant emails for a query.

## Setup Solr for DMS

An FTS backend supported by Dovecot is [Apache Solr][github-solr], a fast and efficient multi-purpose search indexer.

### `compose.yaml` config

Firstly you need a working Solr container, for this the [official docker image][dockerhub-solr] will do:

```yaml
services:
  solr:
    image: solr:latest
    container_name: dms-solr
    environment:
      # As Solr can be quite resource hungry, raise the memory limit to 2GB.
      # The default is 512MB, which may be exhausted quickly.
      SOLR_JAVA_MEM: "-Xms2g -Xmx2g"
    volumes:
      - ./docker-data/solr:/var/solr
    restart: always
```

DMS will connect internally to the `solr` service above. Either have both services in the same `compose.yaml` file, or ensure that the containers are connected to the same docker network.

### Configure Solr for Dovecot

1. Once the Solr container is started, you need to configure a "Solr core" for Dovecot:

    ```bash
    docker exec -it dms-solr /bin/sh
    solr create -c dovecot
    cp -R /opt/solr/contrib/analysis-extras/lib /var/solr/data/dovecot
    ```

    Stop the `dms-solr` container and you should now have a `./data/dovecot` folder in the local bind mount volume.

2. Solr needs a schema that is specifically tailored for Dovecot FTS.

    As of writing of this guide, Solr 9 is the current release. [Dovecot provides the required schema configs][github-dovecot::core-docs] for Solr, copy the following two v9 config files to `./data/dovecot` and rename them accordingly:

    - `solr-config-9.xml` (_rename to `solrconfig.xml`_)
    - `solr-schema-9.xml` (_rename to `schema.xml`_)

    Additionally, remove the `managed-schema.xml` file from `./data/dovecot` and ensure the two files you copied have a [UID and GID of `8983`][dockerfile-solr-uidgid] assigned.

    Start the Solr container once again, you should now have a working Solr core specifically for Dovecot FTS.

3. Configure Dovecot in DMS to connect to this Solr core:

    Create a `10-plugin.conf` file in your `./config/dovecot` folder with this contents:

    ```config
    mail_plugins = $mail_plugins fts fts_solr

    plugin {
      fts = solr
      fts_autoindex = yes
      fts_solr = url=http://solr_solr_1:8983/solr/dovecot/
    }
    ```

    Add a volume mount for that config to your DMS service in `compose.yaml`:

    ```yaml
    volumes:
      - ./docker-data/config/dovecot/10-plugin.conf:/etc/dovecot/conf.d/10-plugin.conf:ro
    ```

### Trigger Dovecot FTS indexing

After following the previous steps, restart DMS and run this command to have Dovecot re-index all mail:

```bash
docker compose exec mailserver doveadm fts rescan -A
```

!!! info "Indexing will take a while depending on how large your mail folders"

    Usually within 15 minutes or so, you should be able to search your mail using the Dovecot FTS feature! :tada:

[dockerhub-solr]: https://hub.docker.com/_/solr
[dockerfile-solr-uidgid]: https://github.com/apache/solr-docker/blob/9cd850b72309de05169544395c83a85b329d6b86/9.6/Dockerfile#L89-L92
[github-solr]: https://github.com/apache/solr
[github-dovecot::core-docs]: https://github.com/dovecot/core/tree/main/doc
