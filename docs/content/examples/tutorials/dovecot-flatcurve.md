---
title: 'Tutorials | Dovecot FTS with Flatcurve'
---

# Dovecot Full Text Search (FTS) using the Flatcurve Backend

Dovecot supports several FTS backends for providing fast and efficient full text searching of e-mails directly from the IMAP server.

As the size of your mail storage grows, the benefits of FTS are especially notable:

- Without FTS, Dovecot would perform a search query by checking each individual email stored for a match, and then repeat this process again from scratch for the exact same query in future.
- Some mail clients (_like Thunderbird_) may provide their own indexing and search features when all mail to search is stored locally, otherwise Dovecot needs to handle the search query (_for example webmail and mobile clients, like Gmail_).
- FTS indexes each mail into a database for querying, where it can skip the cost of inspecting irrelevant emails for a query.

!!! warning "This is a community contributed guide"

    It extends [our official docs for Dovecot FTS][docs::dovecot::full-text-search] with a focus on Dovecot's Flatcurve plugin. DMS does not officially support this integration (yet).

## What is Flatcurve?

[Flatcurve][dovecot-docs::fts-flatcurve] is an FTS backend that became part of Dovecot core with the 2.4 release. Like the [Xapian plugin DMS ships][docs::dovecot::full-text-search] it uses the [Xapian][xapian] library to store indexes locally, so no additional service (_such as Apache Solr_) is needed.

??? "Comparison to Xapian"

    FLatcurve

    - is maintained by the Dovecot developers as part of Dovecot itself, and it is the FTS backend recommended by upstream for local indexing.
    - uses the Dovecot 2.4 `language` settings for tokenizing, stemming and stop words, so search behaviour is consistent with the other Dovecot FTS backends.
    - stores its index in an `fts-flatcurve` directory alongside each mailbox's Dovecot index files (so it is retained in your `mail-data` volume).

## Setup Flatcurve for DMS

### Configure Dovecot to use Flatcurve

Create a `fts-flatcurve-plugin.conf` file in your `./docker-data/dms/config/dovecot/` folder with the following content:

```ini
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
  special_use = \Trash
  fts_autoindex = no
}
mailbox Junk {
  special_use = \Junk
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
  #`mailserver`) at the cost of a much larger index.
  # The default `no` only matches from the start of a word.
  substring_search = no

  # Further optional tuning (commit_limit,`min_term_size,
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

Flatcurve automatically rotates and optimizes its Xapian databases as mail is indexed (_controlled by the `rotate_*` and `optimize_limit` settings_), so unlike `fts-xapian`, a scheduled `doveadm fts optimize` job is not required.

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

[docs::user-patches]: ../../config/advanced/override-defaults/user-patches.md
[docs::dovecot::full-text-search]: ../../config/advanced/full-text-search.md
[docs::dovecot-cf]: ../../config/advanced/override-defaults/dovecot.md
[docs::docker-build]: ./docker-build.md

[dovecot-docs::fts-flatcurve]: https://doc.dovecot.org/2.4.4/core/plugins/fts_flatcurve.html
[xapian]: https://xapian.org/
