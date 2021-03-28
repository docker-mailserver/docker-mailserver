---
title: 'User Management | Aliases'
---

Please read the [Postfix documentation on virtual aliases](http://www.postfix.org/VIRTUAL_README.html#virtual_alias) first.

You can use [`setup.sh`][docs-setupsh] instead of creating and editing files manually. Aliases are managed in `/tmp/docker-mailserver/postfix-virtual.cf`. An alias is a _full_ email address that will either be:

* delivered to an existing account registered in `/tmp/docker-mailserver/postfix-accounts.cf`
* redirected to one or more other email addresses

Alias and target are space separated. An example on a server with domain.tld as its domain:

```cf
# Alias delivered to an existing account
alias1@domain.tld user1@domain.tld

# Alias forwarded to an external email address
alias2@domain.tld external@gmail.com
```

## Configuring RegExp Aliases

Additional regexp aliases can be configured by placing them into `config/postfix-regexp.cf`. The regexp aliases get evaluated after the virtual aliases (`/tmp/docker-mailserver/postfix-virtual.cf`). For example, the following `config/postfix-regexp.cf` causes all email to "test" users to be delivered to `qa@example.com`:

```cf
/^test[0-9][0-9]*@example.com/ qa@example.com
```

## Address Tags (Extension Delimiters) an Alternative to Aliases

Postfix supports so-called address tags, in the form of plus (+) tags - i.e. address+tag@example.com will end up at address@example.com. This is configured by default and the (configurable !) separator is set to `+`. For more info, see [How to use Address Tagging (`user+tag@example.com`) with Postfix](https://www.stevejenkins.com/blog/2011/03/how-to-use-address-tagging-usertagexample-com-with-postfix/) and the [official documentation](http://www.postfix.org/postconf.5.html#recipient_delimiter).

!!! note
    If you do decide to change the configurable separator, you must add the same line to *both* `config/postfix-main.cf` and `config/dovecot.cf`, because Dovecot is acting as the delivery agent. For example, to switch to `-`, add:

```cf
recipient_delimiter = -
```

[docs-setupsh]: ../setup.sh.md
