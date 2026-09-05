---
title: 'Advanced | Full-Text Search'
---

# Full Text Search (FTS)

??? abstract "What is FTS?"

    FTS allows all emails to be indexed so that mail clients can quickly and efficiently search messages by their full text content directly from the IMAP server. As the size of your mail storage grows, the benefits of FTS are especially notable.

    1. Without FTS, Dovecot would perform a search query by checking each individual email stored for a match, and then repeat this process again from scratch for the exact same query in the future.
    2. Some mail clients (_like Thunderbird_) may provide their own indexing and search features when all mail to search is stored locally; otherwise, Dovecot needs to handle the search query (_for example webmail and mobile clients, like Gmail_).
    3. FTS indexes each mail into a database for querying, where it can skip the cost of inspecting irrelevant emails for a query.

    Please be aware that indexing consumes memory and takes up additional disk space.

Dovecot supports a variety of community-supported [FTS indexing backends][dovecot::docs::fts]. DMS provides different levels of support for them.

!!! warning "Do not enable two FTS indexers simultaneously"

    Dovecot supports only one FTS backend at a time. If you migrate, remove the old configuration first, (optionally) prune the old index data to free up space, and only then configure the new indexer.

!!! info "Indexing will take a while depending on how large your mail folders are."

=== "Flatcurve"

    **About**

    [`fts-flatcurve`][dovecot::docs::fts::flatcurve] is an FTS backend that became part of Dovecot core with the 2.4 release.

    ??? info "Comparison to Xapian"

        Like Xapian, Flatcurve uses the [Xapian][web::xapian] library to store indexes locally, so no additional service is needed (unlike solr). But Flatcurve

        - is maintained by the Dovecot developers as part of Dovecot itself, and it is the FTS backend recommended by upstream for local indexing.
        - uses the Dovecot 2.4 `language` settings for tokenizing, stemming and stop words, so search behaviour is consistent with the other Dovecot FTS backends.
        - stores its index in an `fts-flatcurve` directory alongside each mailbox's Dovecot index files (so it is retained in your `mail-data` volume).
        - does not require a recurring job to run `fts optimize` on a schedule.

    **Support Status**

    [Flatcurve][dovecot::docs::fts::flatcurve] was officially introduced with DMS 16.0.0. It will be the preferred FTS indexer going forward because of its straightforward integration into and its first-party support by Dovecot.

    **Setup**

    1. Configure Dovecot to use Flatcurve

        Create a `fts-flatcurve-plugin.conf` file in your `./docker-data/dms/config/dovecot/` folder with the following content:

        ```conf
        # Enable FTS Flatcurve
        mail_plugins {
          fts = yes
          fts_flatcurve = yes
        }

        # Index new mail as it is delivered
        fts_autoindex = yes

        # If FTS lookup or indexing fails, Dovecot
        # falls back to a slow non-indexed search.
        # After the initial indexing (see below)
        # has completed you may prefer to fail such
        # searches instead.
        fts_search_read_fallback = yes

        # Skip autoindexing of folders that grow
        # quickly and are rarely searched:
        mailbox Trash {
          fts_autoindex = no
        }
        mailbox Junk {
          fts_autoindex = no
        }

        # Tokenizing and stemming. Add a `language xx { }`
        # block for each language you expect in your mail.
        # Refer to the Dovecot docs for the languages
        # supported by the `snowball` stemmer.
        #
        # DO NOT enable stopwords together with multiple
        # languages: searches can then miss matches.
        language en {
          default = yes
          language_filters = lowercase snowball english-possessive stopwords
        }

        language_filter_stopwords_dir = /usr/share/dovecot/stopwords
        language_filters = normalizer-icu snowball stopwords
        language_tokenizers = generic email-address
        language_tokenizer_generic_algorithm = simple

        fts flatcurve {
          # Match any part of a word (e.g. `mail` matches
          # `mailserver`) at the cost of a much larger index.
          # The default `no` only matches from the start of a word.
          substring_search = yes

          # Further optional tuning (commit_limit, min_term_size,
          # optimize_limit, rotate_count, rotate_time) is documented
          # upstream. The defaults are sensible for most users.
        }

        service indexer-worker {
          # Limit the size of an indexer-worker's RAM usage
          vsz_limit = 1G
        }
        ```

        Add a volume mount for that config to your DMS service in `compose.yaml`:

        ```yaml
        services:
          mailserver:
            volumes:
              - ./docker-data/dms/config/dovecot/fts-flatcurve-plugin.conf:/etc/dovecot/conf.d/90-fts-flatcurve.conf:ro
        ```

        Alternatively, put the same snippet in [`dovecot.cf`][docs::dovecot-cf] (_DMS copies it to `/etc/dovecot/local.conf`_). That uses the existing config volume and does not need an extra bind-mount.

    2. Trigger Dovecot FTS indexing

        After following the previous steps, restart DMS and run this command to have Dovecot index all existing mail for every account:

        ```bash
        docker compose exec mailserver doveadm index -A -q '*'
        ```

        The `-q` flag queues the work through the `indexer` service instead of running it in the foreground. You can watch progress in the Dovecot logs (`docker compose logs -f mailserver`). Once complete, you should be able to search your mail using the Dovecot FTS feature! :tada:

    **Maintenance**

    Flatcurve automatically rotates and optimizes its Xapian databases as mail is indexed (_controlled by the `rotate_*` and `optimize_limit` settings_).

    Some `doveadm` commands specific to Flatcurve that may be useful:

    ```bash
    # Show index statistics (size, number of mails indexed)
    # per mailbox for a user:
    docker compose exec mailserver doveadm fts flatcurve stats -u user@example.com '*'
    # Verify the index databases of a user are not corrupt:
    docker compose exec mailserver doveadm fts flatcurve check -u user@example.com '*'
    # Drop the index of a user (rebuild it afterwards with `doveadm index`):
    docker compose exec mailserver doveadm fts flatcurve remove -u user@example.com '*'
    # Rebuild the index for everyone from scratch (for example after
    # changing `language` or `substring_search` settings)
    docker compose exec mailserver doveadm fts rescan -A
    docker compose exec mailserver doveadm index -A -q '*'
    ```

=== "Solr"

    **About**

    [Apache Solr][github::repo::apache-solr] is a fast and efficient multi-purpose search indexer.

    **Support Status**

    Support for Solr is entirely community-driven. The build scripts for DMS currently install the `dovecot-solr` package to help users of Solr; the package may be removed if DMS encounters problems with it (especially when building for `arm64`). Bug reports for Solr are not accepted unless they concern the documentation and are accompanied by a pull request to fix the issue.

    **Setup**

    1. Firstly you need a working Solr container

        The [official docker image][dockerhub::solr] will do:

        ```yaml
        services:
          solr:
            image: solr:10.0
            container_name: dms-solr
            command: ["solr-foreground", "--user-managed"]
            environment:
              # As Solr can be quite resource hungry, raise the memory limit to 2GB.
              # The default is 512MB, which may be exhausted quickly.
              SOLR_JAVA_MEM: "-Xms2g -Xmx2g"
              # Current dovecot solr config needs the analysis-extras solr module,
              # so add it with this env var.
              SOLR_MODULES: analysis-extras
            volumes:
              - ./docker-data/solr:/var/solr
            restart: always
        ```

        DMS will connect internally to the `solr` service above. Either have both services in the same `compose.yaml` file, or ensure that the containers are connected to the same docker network.

    2. Configure Solr for Dovecot

        1. Once the Solr container is started, you need to configure a "Solr core" for Dovecot:

            ```bash
            docker exec -it dms-solr /bin/sh
            solr create -c dovecot
            ```

            Stop the `dms-solr` container and you should now have a `./docker-data/solr/data/dovecot` folder in the local bind mount volume.

        2. Solr needs a schema that is specifically tailored for Dovecot FTS.

            As of writing of this guide, Solr 10 is the current release. [Dovecot provides the required schema configs][github::repo::dovecot::docs] for Solr. Copy the following two v9 config files, which also work with Solr 10, to `./docker-data/solr/data/dovecot/conf/` and rename them accordingly:

            - [`solr-config-9.xml`][github::dovecot::solr-config-9] (_rename to `solrconfig.xml`_)
            - [`solr-schema-9.xml`][github::dovecot::solr-schema-9] (_rename to `schema.xml`_)

            Additionally, remove any generated `managed-schema` or `managed-schema.xml` file from `./docker-data/solr/data/dovecot/conf/` and ensure the two files you copied have a [UID and GID of `8983`][solr::docker::uidgid] assigned.

            Start the Solr container once again, you should now have a working Solr core specifically for Dovecot FTS.

        3. Configure Dovecot in DMS to connect to this Solr core:

            Create a `90-fts-solr.conf` file in your `./docker-data/dms/config/dovecot/` folder with this content:

            ```conf
            language en {
              default = yes
            }

            mail_plugins {
              fts = yes
              fts_solr = yes
            }

            fts solr {
            }

            fts_solr_url = http://solr:8983/solr/dovecot/

            fts_autoindex = yes
            fts_search_add_missing = yes
            fts_search_read_fallback = no

            mailbox Trash {
              fts_autoindex = no
            }
            ```

            Excluding Trash from indexing is optional.

            Starting with dovecot 2.4 dovecot fts-solr needs a default language to initialize solr searching. In this example langcode `en` was set as default, but any langcode will do. If you want to enable additional languages add them like this:

            ```conf
            language de {
            }
            ```

            Add a volume mount for that config to your DMS service in `compose.yaml`:

            ```yaml
            services:
              mailserver:
                volumes:
                  - ./docker-data/dms/config/dovecot/90-fts-solr.conf:/etc/dovecot/conf.d/90-fts-solr.conf:ro
            ```

            Alternatively, put the same snippet in [`dovecot.cf`][docs::dovecot-cf] to use the existing config volume instead of an additional bind mount.

    3. Trigger Dovecot FTS indexing

        After following the previous steps, restart DMS and run these commands to reconcile the Solr index and index all existing mail:

        ```bash
        docker compose exec mailserver doveadm fts rescan -A
        docker compose exec mailserver doveadm index -A -q '*'
        ```

=== "Xapian"

    **Support Status**

    The `fts-xapian` plugin is no longer shipped with DMS. It was already unofficially supported since DMS 16.0.0. Use [Flatcurve](#flatcurve) for local FTS indexing instead.

    **Migration**

    When upgrading from a DMS version that included `fts-xapian`, remove any custom Dovecot configuration that enables it, such as `fts-xapian-plugin.conf` or `90-fts-xapian.conf`, and remove any `fts_xapian` cron configuration or bind mount.

    Existing Xapian indexes are stored in a subfolder named `xapian-indexes` inside each user's mailbox directory in your local `mail-data` folder (_`/var/mail` internally_). These indexes are incompatible with Flatcurve and can be deleted before [configuring Flatcurve](#flatcurve). Flatcurve stores its indexes in an `fts-flatcurve` directory alongside each mailbox's Dovecot index files.

[docs::dovecot-cf]: override-defaults/dovecot.md#add-configuration
[docs::discussion::decode2text-notice]: https://github.com/orgs/docker-mailserver/discussions/4461#discussioncomment-13002388

[dockerhub::solr]: https://hub.docker.com/_/solr
[dovecot::docs::fts]: https://doc.dovecot.org/main/core/plugins/fts.html
[dovecot::docs::fts::flatcurve]: https://doc.dovecot.org/main/core/plugins/fts_flatcurve.html
[github::repo::apache-solr]: https://github.com/apache/solr
[github::repo::dovecot::docs]: https://github.com/dovecot/core/tree/main/doc
[github::dovecot::solr-config-9]: https://github.com/dovecot/core/blob/main/doc/solr-config-9.xml
[github::dovecot::solr-schema-9]: https://github.com/dovecot/core/blob/main/doc/solr-schema-9.xml
[solr::docker::uidgid]: https://github.com/apache/solr-docker/blob/main/10.0/Dockerfile
[web::xapian]: https://xapian.org/
