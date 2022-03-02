---
title: 'User Management | Aliases'
---

Please read the [Postfix documentation on virtual aliases](http://www.postfix.org/VIRTUAL_README.html#virtual_alias) first.

You can use [`setup.sh`][docs-setupsh] instead of creating and editing files manually. Aliases are managed in `/tmp/docker-mailserver/postfix-virtual.cf`. An alias is a _full_ email address that will either be:

* delivered to an existing account registered in `/tmp/docker-mailserver/postfix-accounts.cf`
* redirected to one or more other email addresses

Alias and target are space separated. An example on a server with example.com as its domain:

```cf
# Alias delivered to an existing account
alias1@example.com user1@example.com

# Alias forwarded to an external email address
alias2@example.com external-account@gmail.com
```

## Configuring RegExp Aliases

Additional regexp aliases can be configured by placing them into `docker-data/dms/config/postfix-regexp.cf`. The regexp aliases get evaluated after the virtual aliases (container path: `/tmp/docker-mailserver/postfix-virtual.cf`). For example, the following `docker-data/dms/config/postfix-regexp.cf` causes all email sent to "test" users to be delivered to `qa@example.com` instead:

```cf
/^test[0-9][0-9]*@example.com/ qa@example.com
```

## Address Tags (Extension Delimiters) an Alternative to Aliases

Postfix supports so-called address tags, in the form of plus (+) tags - i.e. `address+tag@example.com` will end up at `address@example.com`. This is configured by default and the (configurable !) separator is set to `+`. For more info, see the [official documentation](http://www.postfix.org/postconf.5.html#recipient_delimiter).

!!! note

    If you do decide to change the configurable separator, you must add the same line to *both* `docker-data/dms/config/postfix-main.cf` and `docker-data/dms/config/dovecot.cf`, because Dovecot is acting as the delivery agent. For example, to switch to `-`, add:

```cf
recipient_delimiter = -
```

[docs-setupsh]: ../setup.sh.md
