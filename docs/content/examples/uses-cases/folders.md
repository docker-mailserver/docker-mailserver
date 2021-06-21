---
title: 'Use Cases | Folders'
hide:
  - toc # Hide Table of Contents for this page
---
## Introduction

This provides a solution letting different email clients sharing the same archive folder.
It might also help when troubleshooting sharing `Sent` and `Drafts` folders. 

## Adding a mailbox folder

See [`target/dovecot/15-mailboxes.conf`][gh-config-dovecot-mailboxes] for existing folder definitions you can modify or enable.
Dovecot also [provides their own example config][dovecot-config-mailboxes] for reference, with further information in [their documentation][dovecot-docs-mailboxes].

## Caution

### Adding folders to an existing setup

Handling of newly added mailbox folders can be inconsistent across mail clients:

- Users may experience issues such as archived emails only being available locally.
- Users may need to migrate emails manually between two folders.

### Special Use Mailbox Support

Not all mail clients support Special Use Mailbox (_defined in [RFC 6154][rfc-6154]_), using the exact mailbox name instead. To support those clients, you may prefer to keep the `Speical Use Mailbox` and folder name identical.

### Internationalization (i18n)

Users and mail clients may prefer localized mailbox names instead of English. Take care to test localized names work well, keep in mind concerns such as `Special Use Mailbox` support.

### Email Clients Support
*	Thunderbird

	If new email account is added without `Special Use Mailbox` enabled for archives, Thunderbird suggests and may create `Archives` folder on server.
	If new email account is added after `Special Use Mailbox` enabled for archives, it will pick up the name assigned.

*	Outlook for Android
	
	If new email account is added without `Special Use Mailbox` enabled for archive, it archives locally.
	If new email account is added after `Special Use Mailbox` enabled for archives, it will pick up the name assgined.

*	Spark for Android
	
	If new email account is added without `Special Use Mailbox` enabled for archive, it archives on server folder named `Archive`.
	If new email account is added after `Special Use Mailbox` enabled for archives, it will pick up the name assgined.

* 	Windows Mail
	
	People suggested that it will look for the name instead of `Special Use Mailbox`.

[gh-config-dovecot-mailboxes]: https://github.com/docker-mailserver/docker-mailserver/blob/master/target/dovecot/15-mailboxes.conf
[dovecot-config-mailboxes]: https://github.com/dovecot/core/blob/master/doc/example-config/conf.d/15-mailboxes.conf
[dovecot-docs-mailboxes]: https://doc.dovecot.org/configuration_manual/namespace/#mailbox-settings
[rfc-6154]: https://datatracker.ietf.org/doc/html/rfc6154
