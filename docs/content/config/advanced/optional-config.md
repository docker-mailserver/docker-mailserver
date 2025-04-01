---
title: 'Advanced | Optional Configuration'
hide:
  - toc # Hide Table of Contents for this page
---

## Volumes

DMS has several locations in the container which may be worth persisting externally via [Docker Volumes][docker-docs::volumes].

- Often you will want to prefer [bind mount volumes][docker-docs::volumes::bind-mount] for easy access to files at a local location on your filesystem.
- As a convention for our docs and example configs, the local location has the common prefix `docker-data/dms/` for grouping these related volumes.

!!! info "Reference - Volmes for DMS"

    Our docs may refer to these DMS specific volumes only by name, or the host/container path for brevity.

    - [Config](#volumes-config): `docker-data/dms/config/` => `/tmp/docker-mailserver/`
    - [Mail Storage](#volumes-mail): `docker-data/dms/mail-data/` => `/var/mail/`
    - [State](#volumes-state): `docker-data/dms/mail-state/` => `/var/mail-state/`
    - [Logs](#volumes-log): `docker-data/dms/mail-logs/` => `/var/log/mail/`

### Mail Storage Volume { #volumes-mail }

This is the location where mail is delivered to your mailboxes.

### State Volume { #volumes-state }

Run-time specific state lives here, but so does some data you may want to keep if a failure event occurs (_crash, power loss_).

!!! example "Examples of relevant data"

    - The Postfix queue (eg: mail pending delivery attempt)
    - Fail2Ban blocks.
    - ClamAV signature updates.
    - Redis storage for Rspamd.

!!! info "When a volume is mounted to `/var/mail-state/`"

    - Service run-time data is [consolidated into the `/var/mail-state/` directory][mail-state-folders]. Otherwise the original locations vary and would need to be mounted individually.
    - The original locations are updated with symlinks to redirect to their new path in `/var/mail-state/` (_eg: `/var/lib/redis` => `/var/mail-state/lib-redis/`_).

    Supported services: Postfix, Dovecot, Fail2Ban, Amavis, PostGrey, ClamAV, SpamAssassin, Rspamd & Redis, Fetchmail, Getmail, LogRotate, PostSRSd, MTA-STS.

!!! tip

    Sometimes it is helpful to disable this volume when troubleshooting to verify if the data stored here is in a bad state (_eg: caused by a failure event_).

[mail-state-folders]: https://github.com/docker-mailserver/docker-mailserver/blob/v13.3.1/target/scripts/startup/setup.d/mail_state.sh#L13-L33

### Logs Volume { #volumes-log }

This can be a useful volume to persist for troubleshooting needs for the full set of log files.

### Config Volume { #volumes-config }

Most configuration files for Postfix, Dovecot, etc. are persisted here.

This is a list of all configuration files and directories which are optional, automatically generated / updated by our `setup` CLI, or other internal scripts.

#### Directories

- **sieve-filter:** directory for sieve filter scripts. (Docs: [Sieve][docs-sieve])
- **sieve-pipe:** directory for sieve pipe scripts. (Docs: [Sieve][docs-sieve])
- **opendkim:** DKIM directory. Auto-configurable via [`setup.sh config dkim`][docs-setupsh]. (Docs: [DKIM][docs-dkim])
- **ssl:** SSL Certificate directory if `SSL_TYPE` is set to `self-signed` or `custom`. (Docs: [SSL][docs-ssl])
- **rspamd:** Override directory for custom settings when using Rspamd (Docs: [Rspamd][docs-rspamd-override-d])

#### Files

- **{user_email_address}.dovecot.sieve:** User specific Sieve filter file. (Docs: [Sieve][docs-sieve])
- **before.dovecot.sieve:** Global Sieve filter file, applied prior to the `${login}.dovecot.sieve` filter. (Docs: [Sieve][docs-sieve])
- **after.dovecot.sieve**: Global Sieve filter file, applied after the `${login}.dovecot.sieve` filter. (Docs: [Sieve][docs-sieve])
- **postfix-main.cf:** Every line will be added to the postfix main configuration. (Docs: [Override Postfix Defaults][docs-override-postfix])
- **postfix-master.cf:** Every line will be added to the postfix master configuration. (Docs: [Override Postfix Defaults][docs-override-postfix])
- **postfix-accounts.cf:** User accounts file. Modify via the [`setup.sh email`][docs-setupsh] script.
- **postfix-send-access.cf:** List of users denied sending. Modify via [`setup.sh email restrict`][docs-setupsh].
- **postfix-receive-access.cf:** List of users denied receiving. Modify via [`setup.sh email restrict`][docs-setupsh].
- **postfix-virtual.cf:** Alias configuration file. Modify via [`setup.sh alias`][docs-setupsh].
- **postfix-sasl-password.cf:** listing of relayed domains with their respective `<username>:<password>`. Modify via `setup.sh relay add-auth <domain> <username> [<password>]`. (Docs: [Relay-Hosts Auth][docs::relay-hosts::advanced])
- **postfix-relaymap.cf:** domain-specific relays and exclusions. Modify via `setup.sh relay add-domain` and `setup.sh relay exclude-domain`. (Docs: [Relay-Hosts Senders][docs::relay-hosts::advanced])
- **postfix-regexp.cf:** Regular expression alias file. (Docs: [Aliases][docs-aliases-regex])
- **postfix-regexp-send-only.cf:** Regular expression alias file for sending only. (Docs: [Send-Only Aliases][docs-aliases-send-only])
- **ldap-users.cf:** Configuration for the virtual user mapping `virtual_mailbox_maps`. See the [`setup-stack.sh`][github-commit-setup-stack.sh-L411] script.
- **ldap-groups.cf:** Configuration for the virtual alias mapping `virtual_alias_maps`. See the [`setup-stack.sh`][github-commit-setup-stack.sh-L411] script.
- **ldap-aliases.cf:** Configuration for the virtual alias mapping `virtual_alias_maps`. See the [`setup-stack.sh`][github-commit-setup-stack.sh-L411] script.
- **ldap-domains.cf:** Configuration for the virtual domain mapping `virtual_mailbox_domains`. See the [`setup-stack.sh`][github-commit-setup-stack.sh-L411] script.
- **whitelist_clients.local:** Whitelisted domains, not considered by postgrey. Enter one host or domain per line.
- **spamassassin-rules.cf:** Anti-spam rules for Spamassassin. (Docs: [FAQ - SpamAssassin Rules][docs-faq-spamrules])
- **fail2ban-fail2ban.cf:** Additional config options for `fail2ban.cf`. (Docs: [Fail2Ban][docs-fail2ban])
- **fail2ban-jail.cf:** Additional config options for fail2ban's jail behavior. (Docs: [Fail2Ban][docs-fail2ban])
- **amavis.cf:** replaces the `/etc/amavis/conf.d/50-user` file
- **dovecot.cf:** replaces `/etc/dovecot/local.conf`. (Docs: [Override Dovecot Defaults][docs-override-dovecot])
- **dovecot-quotas.cf:** list of custom quotas per mailbox. (Docs: [Accounts][docs-accounts-quota])
- **user-patches.sh:** this file will be run after all configuration files are set up, but before the postfix, amavis and other daemons are started. (Docs: [FAQ - How to adjust settings with the `user-patches.sh` script][docs-faq-userpatches])
- **rspamd/custom-commands.conf:** list of simple commands to adjust Rspamd modules in an easy way (Docs: [Rspamd][docs-rspamd-commands])

[docker-docs::volumes]: https://docs.docker.com/storage/volumes/
[docker-docs::volumes::bind-mount]: https://docs.docker.com/storage/bind-mounts/

[docs-accounts-quota]: ../../config/user-management.md#quotas
[docs-aliases-regex]: ../../config/user-management.md#configuring-regexp-aliases
[docs-aliases-send-only]: ../../config/user-management.md#send-only-aliases
[docs-dkim]: ../../config/best-practices/dkim_dmarc_spf.md#dkim
[docs-fail2ban]: ../../config/security/fail2ban.md
[docs-faq-spamrules]: ../../faq.md#how-can-i-manage-my-custom-spamassassin-rules
[docs-faq-userpatches]: ../../faq.md#how-to-adjust-settings-with-the-user-patchessh-script
[docs-override-postfix]: ./override-defaults/postfix.md
[docs-override-dovecot]: ./override-defaults/dovecot.md
[docs::relay-hosts::advanced]: ./mail-forwarding/relay-hosts.md#advanced-configuration
[docs-sieve]: ./mail-sieve.md
[docs-setupsh]: ../../config/setup.sh.md
[docs-ssl]: ../../config/security/ssl.md
[docs-rspamd-override-d]: ../security/rspamd.md#manually
[docs-rspamd-commands]: ../security/rspamd.md#with-the-help-of-a-custom-file
[github-commit-setup-stack.sh-L411]: https://github.com/docker-mailserver/docker-mailserver/blob/941e7acdaebe271eaf3d296b36d4d81df4c54b90/target/scripts/startup/setup-stack.sh#L411
