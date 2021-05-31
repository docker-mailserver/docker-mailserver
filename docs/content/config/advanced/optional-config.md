---
title: 'Advanced | Optional Configuration'
hide:
  - toc # Hide Table of Contents for this page
---

This is a list of all configuration files and directories which are optional or automatically generated in your `config` directory.

## Directories

- **sieve-filter:** directory for sieve filter scripts. (Docs: [Sieve][docs-sieve])
- **sieve-pipe:** directory for sieve pipe scripts. (Docs: [Sieve][docs-sieve])
- **opendkim:** DKIM directory. Auto-configurable via [`setup.sh config dkim`][docs-setupsh]. (Docs: [DKIM][docs-dkim])
- **ssl:** SSL Certificate directory. (Docs: [SSL][docs-ssl])

## Files

- **{user_email_address}.dovecot.sieve:** User specific Sieve filter file. (Docs: [Sieve][docs-sieve])
- **before.dovecot.sieve:** Global Sieve filter file, applied prior to the `${login}.dovecot.sieve` filter. (Docs: [Sieve][docs-sieve])
- **after.dovecot.sieve**: Global Sieve filter file, applied after the `${login}.dovecot.sieve` filter. (Docs: [Sieve][docs-sieve])
- **postfix-main.cf:** Every line will be added to the postfix main configuration. (Docs: [Override Postfix Defaults][docs-override-postfix])
- **postfix-master.cf:** Every line will be added to the postfix master configuration. (Docs: [Override Postfix Defaults][docs-override-postfix])
- **postfix-accounts.cf:** User accounts file. Modify via the [`setup.sh email`][docs-setupsh] script.
- **postfix-send-access.cf:** List of users denied sending. Modify via [`setup.sh email restrict`][docs-setupsh].
- **postfix-receive-access.cf:** List of users denied receiving. Modify via [`setup.sh email restrict`][docs-setupsh].
- **postfix-virtual.cf:** Alias configuration file. Modify via [`setup.sh alias`][docs-setupsh].
- **postfix-sasl-password.cf:** listing of relayed domains with their respective `<username>:<password>`. Modify via `setup.sh relay add-auth <domain> <username> [<password>]`. (Docs: [Relay-Hosts Auth][docs-relayhosts-senderauth])
- **postfix-relaymap.cf:** domain-specific relays and exclusions. Modify via `setup.sh relay add-domain` and `setup.sh relay exclude-domain`. (Docs: [Relay-Hosts Senders][docs-relayhosts-senderhost])
- **postfix-regexp.cf:** Regular expression alias file. (Docs: [Aliases][docs-aliases-regex])
- **ldap-users.cf:** Configuration for the virtual user mapping `virtual_mailbox_maps`. See the [`setup-stack.sh`][github-commit-setup-stack.sh-L411] script.
- **ldap-groups.cf:** Configuration for the virtual alias mapping `virtual_alias_maps`. See the [`setup-stack.sh`][github-commit-setup-stack.sh-L411] script.
- **ldap-aliases.cf:** Configuration for the virtual alias mapping `virtual_alias_maps`. See the [`setup-stack.sh`][github-commit-setup-stack.sh-L411] script.
- **ldap-domains.cf:** Configuration for the virtual domain mapping `virtual_mailbox_domains`. See the [`setup-stack.sh`][github-commit-setup-stack.sh-L411] script.
- **whitelist_clients.local:** Whitelisted domains, not considered by postgrey. Enter one host or domain per line.
- **spamassassin-rules.cf:** Antispam rules for Spamassassin. (Docs: [FAQ - SpamAssassin Rules][docs-faq-spamrules])
- **fail2ban-fail2ban.cf:** Additional config options for `fail2ban.cf`. (Docs: [Fail2Ban][docs-fail2ban])
- **fail2ban-jail.cf:** Additional config options for fail2ban's jail behaviour. (Docs: [Fail2Ban][docs-fail2ban])
- **amavis.cf:** replaces the `/etc/amavis/conf.d/50-user` file
- **dovecot.cf:** replaces `/etc/dovecot/local.conf`. (Docs: [Override Dovecot Defaults][docs-override-dovecot])
- **dovecot-quotas.cf:** list of custom quotas per mailbox. (Docs: [Accounts][docs-accounts-quota])
- **user-patches.sh:** this file will be run after all configuration files are set up, but before the postfix, amavis and other daemons are started. (Docs: [FAQ - How to adjust settings with the `user-patches.sh` script][docs-faq-userpatches])

[docs-accounts-quota]: ../../config/user-management/accounts.md#notes
[docs-aliases-regex]: ../../config/user-management/aliases.md#configuring-regexp-aliases
[docs-dkim]: ../../config/best-practices/dkim.md
[docs-fail2ban]: ../../config/security/fail2ban.md
[docs-faq-spamrules]: ../../faq.md#how-can-i-manage-my-custom-spamassassin-rules
[docs-faq-userpatches]: ../../faq.md#how-to-adjust-settings-with-the-user-patchessh-script
[docs-override-postfix]: ./override-defaults/postfix.md
[docs-override-dovecot]: ./override-defaults/dovecot.md
[docs-relayhosts-senderauth]: ./mail-forwarding/relay-hosts.md#sender-dependent-authentication
[docs-relayhosts-senderhost]: ./mail-forwarding/relay-hosts.md#sender-dependent-relay-host
[docs-sieve]: ./mail-sieve.md
[docs-setupsh]: ../../config/setup.sh.md
[docs-ssl]: ../../config/security/ssl.md
[github-commit-setup-stack.sh-L411]: https://github.com/docker-mailserver/docker-mailserver/blob/941e7acdaebe271eaf3d296b36d4d81df4c54b90/target/scripts/startup/setup-stack.sh#L411
