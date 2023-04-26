---
title: 'Use Cases | Customize Mailbox Folders'
hide:
  - toc # Hide Table of Contents for this page
---

# Mailboxes (_aka IMAP Folders_)

`INBOX` is setup as the private [`inbox` namespace][dovecot-docs-namespaces]. By default [`target/dovecot/15-mailboxes.conf`][github-config-dovecot-mailboxes] configures the special IMAP folders `Drafts`, `Sent`, `Junk` and `Trash` to be automatically created and subscribed. They are all assigned to the private [`inbox` namespace][dovecot-docs-namespaces] (_which implicitly provides the `INBOX` folder_).

These IMAP folders are considered special because they add a [_"SPECIAL-USE"_ attribute][rfc-6154], which is a standardized way to communicate to mail clients that the folder serves a purpose like storing spam/junk mail (`\Junk`) or deleted mail (`\Trash`). This differentiates them from regular mail folders that you may use for organizing.

## Adding a mailbox folder

See [`target/dovecot/15-mailboxes.conf`][github-config-dovecot-mailboxes] for existing mailbox folders which you can modify or uncomment to enable some other common mailboxes. For more information try the [official Dovecot documentation][dovecot-docs-mailboxes].

The `Archive` special IMAP folder may be useful to enable. To do so, make a copy of [`target/dovecot/15-mailboxes.conf`][github-config-dovecot-mailboxes] and uncomment the `Archive` mailbox definition. Mail clients should understand that this folder is intended for archiving mail due to the [`\Archive` _"SPECIAL-USE"_ attribute][rfc-6154].

With the provided [compose.yaml][github-config-dockercompose] example, a volume bind mounts the host directory `docker-data/dms/config/` to the container location `/tmp/docker-mailserver/`. Config file overrides should instead be mounted to a different location as described in [Overriding Configuration for Dovecot][docs-config-overrides-dovecot]:

```yaml
volumes:
  - ./docker-data/dms/config/dovecot/15-mailboxes.conf:/etc/dovecot/conf.d/15-mailboxes.conf:ro
```

## Caution

### Adding folders to an existing setup

Handling of newly added mailbox folders can be inconsistent across mail clients:

- Users may experience issues such as archived emails only being available locally.
- Users may need to migrate emails manually between two folders.

### Support for `SPECIAL-USE` attributes

Not all mail clients support the `SPECIAL-USE` attribute for mailboxes (_defined in [RFC 6154][rfc-6154]_). These clients will treat the mailbox folder as any other, using the name assigned to it instead.

Some clients may still know to treat these folders for their intended purpose if the mailbox name matches the common names that the `SPECIAL-USE` attributes represent (_eg `Sent` as the mailbox name for `\Sent`_).

### Internationalization (i18n)

Usually the mail client will know via context such as the `SPECIAL-USE` attribute or common English mailbox names, to provide a localized label for the users preferred language.

Take care to test localized names work well as well.

### Email Clients Support

- If a new mail account is added without the `SPECIAL-USE` attribute enabled for archives:
    - **Thunderbird** suggests and may create an `Archives` folder on the server.
    - **Outlook for Android** archives to a local folder.
    - **Spark for Android** archives to server folder named `Archive`.
- If a new mail account is added after the `SPECIAL-USE` attribute is enabled for archives:
    - **Thunderbird**, **Outlook for Android** and **Spark for Android** will use the mailbox folder name assigned.

!!! caution "Windows Mail"

    **Windows Mail** has been said to ignore `SPECIAL-USE` attribute and look only at the mailbox folder name assigned.

!!! note "Needs citation"

    This information is provided by the community.

    It presently lacks references to confirm the behaviour. If any information is incorrect please let us know! :smile:


[docs-config-overrides-dovecot]: ../../config/advanced/override-defaults/dovecot.md#override-configuration
[github-config-dockercompose]: https://github.com/docker-mailserver/docker-mailserver/blob/master/compose.yaml
[github-config-dovecot-mailboxes]: https://github.com/docker-mailserver/docker-mailserver/blob/master/target/dovecot/15-mailboxes.conf
[dovecot-docs-namespaces]: https://doc.dovecot.org/configuration_manual/namespace/#namespace-inbox
[dovecot-docs-mailboxes]: https://doc.dovecot.org/configuration_manual/namespace/#mailbox-settings
[rfc-6154]: https://datatracker.ietf.org/doc/html/rfc6154
