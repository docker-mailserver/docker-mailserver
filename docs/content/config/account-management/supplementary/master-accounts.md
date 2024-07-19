---
title: 'Account Management | Master Accounts (Dovecot)'
hide:
  - toc # Hide Table of Contents for this page
---

This feature is useful for administrative tasks like hot backups.

!!! note

    This feature is presently [not supported with `ACCOUNT_PROVISIONER=LDAP`][dms::feature::dovecot-master-accounts::caveat-ldap].

!!! info

    A _Master Account_:

    - Can login as any user (DMS account) and access their mailbox.
    - Is not associated to a separate DMS account, nor is it a DMS account itself.

    ---

    **`setup` CLI support**

    Use the `setup dovecot-master <add|update|del|list>` commands. These are roughly equivalent to the `setup email` subcommands.

    ---

    **Config file:** `docker-data/dms/config/dovecot-masters.cf`

    The config format is the same as [`postfix-accounts.cf` for `ACCOUNT_PROVISIONER=FILE`][docs::account-management::file::accounts].

    The only difference is the account field has no `@domain-part` suffix, it is only a username.

??? abstract "Technical Details"

    [The _Master Accounts_ feature][dms::feature::dovecot-master-accounts] in DMS configures the [Dovecot Master Users][dovecot-docs::auth::master-users] feature with the Dovecot setting [`auth_master_user_separator`][dovecot-docs::config::auth-master-user-separator] (_where the default value is `*`_).

## Login via Master Account

!!! info

    To login as another DMS account (`user@example.com`) with POP3 or IMAP, use the following credentials format:

    - Username: `<LOGIN USERNAME>*<MASTER USER>` (`user@example.com*admin`)
    - Password: `<MASTER PASSWORD>`

!!! example "Verify login functionality"

    In the DMS container, you can verify with the `testsaslauthd` command:

    ```bash
    # Prerequisites:
    # A regular DMS account to test login through a Master Account:
    setup email add user@example.com secret
    # Add a new Master Account:
    setup dovecot-master add admin top-secret
    ```

    ```bash
    # Login with credentials format as described earlier:
    testsaslauthd -u 'user@example.com*admin' -p 'top-secret'
    ```

    Alternatively, any mail client should be able to login the equivalent credentials.

[dms::feature::dovecot-master-accounts]: https://github.com/docker-mailserver/docker-mailserver/pull/2535
[dms::feature::dovecot-master-accounts::caveat-ldap]: https://github.com/docker-mailserver/docker-mailserver/pull/2535#issuecomment-1118056745
[dovecot-docs::auth::master-users]: https://doc.dovecot.org/configuration_manual/authentication/master_users/
[dovecot-docs::config::auth-master-user-separator]: https://doc.dovecot.org/settings/core/#core_setting-auth_master_user_separator
[docs::account-management::file::accounts]: ../provisioner/file.md#accounts
