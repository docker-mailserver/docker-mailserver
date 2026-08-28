---
title: 'Tutorials | Dovecot FTS with Flatcurve'
---

# Dovecot Full Text Search (FTS) using the Flatcurve Backend

Dovecot supports several FTS backends for providing fast and efficient full text searching of e-mails directly from the IMAP server.

As the size of your mail storage grows, the benefits of FTS are especially notable:

- Without FTS, Dovecot would perform a search query by checking each individual email stored for a match, and then repeat this process again from scratch for the exact same query in future.
- Some mail clients (_like Thunderbird_) may provide their own indexing and search features when all mail to search is stored locally, otherwise Dovecot needs to handle the search query (_for example webmail and mobile clients, like Gmail_).
- FTS indexes each mail into a database for querying instead, where it can skip the cost of inspecting irrelevant emails for a query.

!!! warning "This is a community contributed guide"

    It extends [our official docs for Dovecot FTS][docs::dovecot::full-text-search] with a focus on Dovecot's Flatcurve plugin. DMS does not officially support this integration.

## What is Flatcurve?

[Flatcurve][dovecot-docs::fts-flatcurve] is an FTS backend that became part of Dovecot core with the 2.4 release. Like the [Xapian plugin DMS ships][docs::dovecot::full-text-search] it uses the [Xapian][xapian] library to store indexes locally, so no additional service (_such as Apache Solr_) is needed.

Compared to `fts-xapian`, Flatcurve:

- Is maintained by the Dovecot developers as part of Dovecot itself, and is the FTS backend recommended by upstream for local indexing.
- Uses the Dovecot 2.4 `language` settings for tokenizing, stemming and stop words, so search behaviour is consistent with the other Dovecot FTS backends.
- Stores its index in an `fts-flatcurve` directory alongside each mailbox's Dovecot index files (_`/var/mail/<domain>/<user>/...` internally, so it is retained in your `mail-data` volume_).

!!! note "Requirements"

    Flatcurve requires Dovecot 2.4, which DMS provides since the base image was updated to Debian 13 (_currently the `:edge` image tag, and the next release after `v15.1.0`_). DMS releases up to `v15.x` provide Dovecot 2.3 and cannot use this guide.

## Setup Flatcurve for DMS

### Add the required `dovecot-flatcurve` package

The plugin is packaged by Debian as `dovecot-flatcurve` (_for both AMD64 and ARM64_). As the official DMS image does not include it, you'll need to add the package to your own image (_extending a DMS release as a base image_), or via our [`user-patches.sh` feature][docs::user-patches]:

<!-- This empty quote block is purely for a visual border -->
!!! quote ""

    === "`user-patches.sh`"

        If you'd prefer to avoid a custom image build. This approach is simpler but with the caveat that any time the container is restarted, you'll have a delay as the package is installed each time.

        ```bash
        #!/bin/bash

        apt-get update && apt-get install --yes --no-install-recommends dovecot-flatcurve
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
                RUN apt-get update \
                  && apt-get install --yes --no-install-recommends dovecot-flatcurve \
                  && rm -rf /var/lib/apt/lists/*
        ```

        This approach only needs to install the package once with the image build itself which minimizes the delay of container startup.

        - Just run `DMS_TAG='16.0' docker compose up` and it will pull the DMS image, then build your custom DMS image to run a new container instance.
        - Updating to a new DMS release is straight-forward, just adjust the `DMS_TAG` ENV value or change the image tag directly in `compose.yaml` as you normally would to upgrade an image.
        - If you make future changes to the `dockerfile_inline` that don't seem to be applied, you may need to force a rebuild with `DMS_TAG='16.0' docker compose up --build`.

!!! tip "`DOVECOT_COMMUNITY_REPO=1` builds"

    If you [build DMS yourself][docs::docker-build] with the `DOVECOT_COMMUNITY_REPO=1` build ARG, the Dovecot CE repo also provides the package under the same `dovecot-flatcurve` name.

### Configure Dovecot to use Flatcurve

Create a `fts-flatcurve-plugin.conf` file in your `./docker-data/dms/config/dovecot/` folder with this contents:

```config
mail_plugins {
  fts = yes
  fts_flatcurve = yes
}

# Index new mail as it is delivered:
fts_autoindex = yes
# When the index does not yet cover a mailbox, Dovecot falls back to a slow non-indexed search.
# Once the initial indexing (see below) has completed you may prefer to fail such searches instead:
# fts_search_read_fallback = no

# Tokenizing and stemming. Add a `language xx { }` block for each language you expect in your mail.
# Refer to the Dovecot docs for the languages supported by the `snowball` stemmer.
language_filters = normalizer-icu snowball stopwords
language_tokenizers = generic email-address
language_tokenizer_generic_algorithm = simple

language en {
  default = yes
  filters = lowercase snowball english-possessive stopwords
}

fts flatcurve {
  # Match any part of a word (e.g. `mail` matches `mailserver`) at the cost of a much larger index.
  # The default `no` only matches from the start of a word.
  substring_search = no

  # Further optional tuning (`commit_limit`, `min_term_size`, `optimize_limit`, `rotate_count`, `rotate_time`)
  # is documented upstream. The defaults are sensible for most users.
}

service indexer-worker {
  # limit size of indexer-worker RAM usage, ex: 512M, 1G, 2G
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

!!! warning "Do not enable both `fts_xapian` and `fts_flatcurve`"

    Dovecot supports only one FTS backend at a time. If you previously followed the [Xapian guide][docs::dovecot::full-text-search], remove that config file and mount before switching. The old `xapian-indexes` folders inside your `mail-data` volume can be deleted to reclaim disk space.

### Trigger Dovecot FTS indexing

After following the previous steps, restart DMS and run this command to have Dovecot index all existing mail for every account:

```bash
docker compose exec mailserver doveadm index -A -q '*'
```

!!! info "Indexing will take a while depending on how large your mail folders are"

    The `-q` flag queues the work through the `indexer` service instead of running it in the foreground. You can watch progress in the Dovecot logs (`docker compose logs -f mailserver`). Once complete, you should be able to search your mail using the Dovecot FTS feature! :tada:

### Maintenance

Flatcurve automatically rotates and optimizes its Xapian databases as mail is indexed (_controlled by the `rotate_*` and `optimize_limit` settings_), so unlike `fts-xapian` a scheduled `doveadm fts optimize` job is not required.

Some `doveadm` commands specific to Flatcurve that may be useful:

```bash
# Show index statistics (size, number of mails indexed) per mailbox for a user:
docker compose exec mailserver doveadm fts flatcurve stats -u user@example.com '*'
# Verify the index databases of a user are not corrupt:
docker compose exec mailserver doveadm fts flatcurve check -u user@example.com '*'
# Drop the index of a user (rebuild it afterwards with `doveadm index`):
docker compose exec mailserver doveadm fts flatcurve remove -u user@example.com '*'
```

To rebuild the index for everyone from scratch (_for example after changing `language` or `substring_search` settings_):

```bash
docker compose exec mailserver doveadm fts rescan -A
docker compose exec mailserver doveadm index -A -q '*'
```

[docs::user-patches]: ../../config/advanced/override-defaults/user-patches.md
[docs::dovecot::full-text-search]: ../../config/advanced/full-text-search.md
[docs::docker-build]: ./docker-build.md

[dovecot-docs::fts-flatcurve]: https://doc.dovecot.org/2.4.4/core/plugins/fts_flatcurve.html
[xapian]: https://xapian.org/
