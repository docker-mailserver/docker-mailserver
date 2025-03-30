# Dovecot Full Text Search (FTS) using the Solr Backend

Dovecot supports several FTS backends for providing fast and efficient full text searching of e-mails directly from the IMAP server.

As the size of your mail storage grows, the benefits of FTS are especially notable:

- Without FTS, Dovecot would perform a search query by checking each individual email stored for a match, and then repeat this process again from scratch for the exact same query in future.
- Some mail clients (_like Thunderbird_) may provide their own indexing and search features when all mail to search is stored locally, otherwise Dovecot needs to handle the search query (_for example webmail and mobile clients, like Gmail_).
- FTS indexes each mail into a database for querying instead, where it can skip the cost of inspecting irrelevant emails for a query.

!!! warning "This is a community contributed guide"

    It extends [our official docs for Dovecot FTS][docs::dovecot::full-text-search] with a focus on Apache Solr. DMS does not officially support this integration.

## Setup Solr for DMS

An FTS backend supported by Dovecot is [Apache Solr][github-solr], a fast and efficient multi-purpose search indexer.

### Add the required `dovecot-solr` package

As the official DMS image does not provide `dovecot-solr`, you'll need to include the package in your own image (_extending a DMS release as a base image_), or via our [`user-patches.sh` feature][docs::user-patches]:

<!-- This empty quote block is purely for a visual border -->
!!! quote ""

    === "`user-patches.sh`"

        If you'd prefer to avoid a custom image build. This approach is simpler but with the caveat that any time the container is restarted, you'll have a delay as the package is installed each time.

        ```bash
        #!/bin/bash

        apt-get update && apt-get install dovecot-solr
        ```

    === "`compose.yaml`"

        A custom DMS image does not add much friction. You do not need a separate `Dockerfile` as Docker Compose supports building from an inline `Dockerfile` in your `compose.yaml`.

        The `image` key of the service is swapped for the `build` key instead, as shown below:

        ```yaml
        services:
          mailserver:
            hostname: mail.example.com
            # The `image` setting now represents the tag for the local build configured below:
            image: local/dms:${DMS_TAG?Must set DMS image tag}
            # Local build (no need to try pull `image` remotely):
            pull_policy: build
            # Add this `build` section to your real `compose.yaml` for your DMS service:
            build:
              dockerfile_inline: |
                FROM docker.io/mailserver/docker-mailserver:${DMS_TAG?Must set DMS image tag}
                RUN apt-get update && apt-get install dovecot-solr
        ```

        This approach only needs to install the package once with the image build itself which minimizes the delay of container startup.

        - Just run `DMS_TAG='14.0' docker compose up` and it will pull the DMS image, then build your custom DMS image to run a new container instance.
        - Updating to a new DMS release is straight-forward, just adjust the `DMS_TAG` ENV value or change the image tag directly in `compose.yaml` as you normally would to upgrade an image.
        - If you make future changes to the `dockerfile_inline` that don't seem to be applied, you may need to force a rebuild with `DMS_TAG='14.0' docker compose up --build`.

!!! note "Why doesn't DMS include `dovecot-solr`?"

    This integration is not officially supported in DMS as no maintainer is able to provide troubleshooting support.

    Prior to v14, the package was included but the community contributed guide had been outdated for several years that it was non-functional. It was decided that it was better to drop support and docs, however some DMS users voiced active use of Solr and it's benefits over Xapian for FTS which led to these revised docs.

    **ARM64 builds do not have support for `dovecot-solr`**. Additionally the [user demand for including `dovecot-solr` is presently too low][gh-dms::feature-request::dovecot-solr-package] to justify vs the minimal effort to add additional packages as shown above.

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
      fts_solr = url=http://dms-solr:8983/solr/dovecot/
    }
    ```

    Add a volume mount for that config to your DMS service in `compose.yaml`:

    ```yaml
    services:
      mailserver:
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

### Compatibility

Since Solr 9.8.0 was released (Jan 2025), a breaking change [deprecates support for `<lib>` directives][solr::9.8::lib-directive] which is presently used by the Dovecot supplied Solr config (`solr-config-9.xml`) to automatically load additional jars required.

To enable support for `<lib>` directives, add the following ENV to your `solr` container:

```yaml
services:
  solr:
    environment:
      SOLR_CONFIG_LIB_ENABLED: true
```

!!! warning "Solr 10"

    From the Solr 10 release onwards, this opt-in ENV will no longer be available.

    If Dovecot has not updated their example Solr config ([upstream PR][dovecot::pr::solr-config-lib]), you will need to manually modify the Solr XML config to remove the `<lib>` directives and replace the suggested ENV `SOLR_CONFIG_LIB_ENABLED=true` with `SOLR_MODULES=analysis-extras`.

[docs::user-patches]: ../../config/advanced/override-defaults/user-patches.md
[docs::dovecot::full-text-search]: ../../config/advanced/full-text-search.md
[gh-dms::feature-request::dovecot-solr-package]: https://github.com/docker-mailserver/docker-mailserver/issues/4052

[dockerhub-solr]: https://hub.docker.com/_/solr
[dockerfile-solr-uidgid]: https://github.com/apache/solr-docker/blob/9cd850b72309de05169544395c83a85b329d6b86/9.6/Dockerfile#L89-L92
[github-solr]: https://github.com/apache/solr
[github-dovecot::core-docs]: https://github.com/dovecot/core/tree/main/doc

[solr::9.8::lib-directive]: https://issues.apache.org/jira/browse/SOLR-16781
[dovecot::pr::solr-config-lib]: https://github.com/dovecot/core/pull/238
