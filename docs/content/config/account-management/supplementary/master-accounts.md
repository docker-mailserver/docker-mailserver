---
title: 'Account Management | Master Accounts (Dovecot)'
---

## Introduction

A master account:

- Can login as any user (DMS account) and access their mailbox.
- Is not associated to a separate DMS account, nor is it a DMS account itself.

This feature is useful for administrative tasks like hot backups.

!!! note

    This feature is presently [not supported with LDAP][dms::feature::dovecot-master-accounts::caveat-ldap] account provisioning.


??? abstract "Technical Details"

    [The _Master Accounts_ feature][dms::feature::dovecot-master-accounts] in DMS configures the [Dovecot Master Users][dovecot-docs::auth::master-users] feature with the Dovecot setting [`auth_master_user_separator`][dovecot-docs::config::auth-master-user-separator] using the upstream default value (`*`).

## Configuration

The DMS `setup` CLI can create, update, delete, and list master accounts. Run `setup help` for usage.

## Login via Master Account

To login as another DMS account (`user@example.com`) with POP3/IMAP, use the following credentials format:

- Username: `<LOGIN USERNAME>*<MASTER USER>` (`user@example.com*admin`)
- Password: `<MASTER PASSWORD>`

!!! example "Verify login functionality"

    In the DMS container, you can verify with the `testsaslauthd` command:

    ```bash
    # A regular DMS account to test login through a master account:
    setup email add user@example.com secret
    # Add a new master account:
    setup dovecot-master add admin top-secret

    testsaslauthd -u 'user@example.com*admin' -p 'top-secret'
    ```

    Alternatively, any mail client should be able to login the equivalent credentials.

[dms::feature::dovecot-master-accounts]: https://github.com/docker-mailserver/docker-mailserver/pull/2535
[dms::feature::dovecot-master-accounts::caveat-ldap]: https://github.com/docker-mailserver/docker-mailserver/pull/2535#issuecomment-1118056745
[dovecot-docs::auth::master-users]: https://doc.dovecot.org/configuration_manual/authentication/master_users/
[dovecot-docs::config::auth-master-user-separator]: https://doc.dovecot.org/settings/core/#core_setting-auth_master_user_separator
