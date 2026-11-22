---
title: 'Advanced | Change Detection'
---

DMS runs a _change detection_ service (`changedetector`) that watches a fixed set of files and applies changes to the running services. This is why `setup email add` and the other `setup` commands that edit the [config volume][docs::optional-config::volumes-config] take effect without restarting the container.

!!! info "Overview"

    - The service is always started, there is no ENV to disable it.
    - It polls, it does not use file system notifications. The wait between two checks is [`DMS_CONFIG_POLL`][docs::env::dms-config-poll] seconds (_default: `2`_), so a change is applied a short while after it was made.
    - It compares the SHA-512 hashes of the monitored files. Only a change to the content of a file counts, touching a file does not.
    - Only the files listed on this page are monitored. For all other files, see [Other Files](#other-files).

## Monitored Files

### Config Volume

These files in `docker-data/dms/config/` (_`/tmp/docker-mailserver/` in the container_) are monitored:

- `postfix-accounts.cf`
- `postfix-virtual.cf`
- `postfix-aliases.cf`
- `postfix-regexp.cf`
- `postfix-relaymap.cf`
- `postfix-sasl-password.cf`
- `dovecot-quotas.cf`
- `dovecot-masters.cf`
- Every file in the `rspamd/` directory (_only with `ENABLE_RSPAMD=1`_)

A file that does not exist is skipped. When it is created later, that counts as a change.

### TLS Certificates

- With `SSL_TYPE=manual`: the files that `SSL_CERT_PATH`, `SSL_KEY_PATH`, `SSL_ALT_CERT_PATH` and `SSL_ALT_KEY_PATH` point to.
- With `SSL_TYPE=letsencrypt`: `/etc/letsencrypt/acme.json` (_the certificate store of Traefik_) and the `*.pem` files in `/etc/letsencrypt/live/<NAME>/`, where `<NAME>` is each of `SSL_DOMAIN`, the FQDN of the container (_`mail.example.com`_) and its domain name (_`example.com`_).

## What Happens on a Change

At the end of the container setup, DMS stores the hash of each monitored file. A change is detected when a hash differs from the stored one (_or is new_). Then the service logs `Change detected`, applies the changes below, and stores the new hashes.

| Changed file                                      | What DMS applies                                                                                                 |
| :------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------- |
| `postfix-accounts.cf`, `postfix-virtual.cf`       | The managed domains (_`/etc/postfix/vhost`_), the Dovecot and Postfix accounts, the virtual aliases, the relay config |
| `postfix-aliases.cf`                              | The Dovecot and Postfix accounts, the system aliases (_`/etc/aliases`_)                                          |
| `postfix-regexp.cf`                               | The regexp aliases                                                                                               |
| `dovecot-quotas.cf`, `dovecot-masters.cf`         | The Dovecot and Postfix accounts                                                                                 |
| `postfix-relaymap.cf`, `postfix-sasl-password.cf` | The relay config                                                                                                 |
| Files in `rspamd/`                                | Changed `override.d/` files are copied to `/etc/rspamd/override.d/`, a changed `custom-commands.conf` is applied, and Rspamd is reloaded |
| Certificate files of `SSL_TYPE=manual`            | The certificates are copied to the directory that Postfix and Dovecot use                                        |
| `acme.json`                                       | The certificate is extracted from it                                                                             |

Every detected change ends with a reload of Postfix and (_unless `SMTP_ONLY=1`_) Dovecot. With `ENABLE_AMAVIS=1`, Amavis is reloaded too when the managed domains changed. Changed `.pem` files in `/etc/letsencrypt/live/` (_without `acme.json`_) only trigger these reloads.

!!! note "`ACCOUNT_PROVISIONER=LDAP`"

    With the LDAP provisioner only the TLS certificates and the `rspamd/` files are handled (_plus the reloads_). The accounts, aliases and relay config of the table above are not processed, as the accounts are not managed through these files.

## Other Files

Changes to files that are not monitored, like `postfix-main.cf`, `postfix-master.cf`, `dovecot.cf` or `user-patches.sh`, are only applied when a new container starts. Restarting an existing container skips most of the setup, so recreate it (_for example with `docker compose up -d --force-recreate`_).

## Logs

The service writes to its own log file:

```bash
docker exec <CONTAINER NAME> tail -f /var/log/supervisor/changedetector.log
```

- `Change detected` is logged at the default `LOG_LEVEL=info`.
- `LOG_LEVEL=debug` also logs when the services are reloaded and when the handling of the change completed.
- `LOG_LEVEL=trace` also logs which parts of the config are regenerated, like `Regenerating accounts (Dovecot + Postfix)`.

## Limitations

- Deleting a monitored file is detected, and the services are reloaded, but nothing that is derived from the file is regenerated. Empty the file instead of deleting it, or recreate the container.
- The files written by `setup email restrict` (_`postfix-send-access.cf` and `postfix-receive-access.cf`_) are not monitored.

??? abstract "Technical Details"

    - The service is the script [`check-for-changes.sh`][gh::check-for-changes], which is started by `supervisord`. The monitored files are listed in [`change-detection.sh`][gh::monitored-configs].
    - While the service applies a change, it holds the lock file `check-for-changes.sh.lock` in the config volume. Containers that share a config volume therefore do not apply changes at the same time. A lock that is older than one minute is considered stale and removed.

[docs::env::dms-config-poll]: ../environment.md#dms_config_poll
[docs::optional-config::volumes-config]: ./optional-config.md#volumes-config
[gh::check-for-changes]: https://github.com/docker-mailserver/docker-mailserver/blob/master/target/scripts/check-for-changes.sh
[gh::monitored-configs]: https://github.com/docker-mailserver/docker-mailserver/blob/master/target/scripts/helpers/change-detection.sh
