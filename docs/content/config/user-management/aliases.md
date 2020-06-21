Please first read [Postfix documentation on virtual aliases](http://www.postfix.org/VIRTUAL_README.html#virtual_alias).

### Configuring aliases

You can use [setup.sh](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh#alias) instead of creating and editing files manually.

Aliases are managed in `/tmp/docker-mailserver/postfix-virtual.cf`.

An alias is a _full_ email address that will either be:

* delivered to an existing account registered in `/tmp/docker-mailserver/postfix-accounts.cf`
* redirected to one or more other email addresses

Alias and target are space separated.

Example (on a server with domain.tld as its domain):

    # Alias delivered to an existing account
    alias1@domain.tld user1@domain.tld

    # Alias forwarded to an external email address
    alias2@domain.tld external@gmail.com

### Configuring regexp aliases

Additional regexp aliases can be configured by placing them into `config/postfix-regexp.cf`. The regexp aliases get evaluated after the virtual aliases (`/tmp/docker-mailserver/postfix-virtual.cf`).

For example, the following `config/postfix-regexp.cf` causes all email to "test" users to be delivered to qa@example.com:

```
/^test[0-9][0-9]*@example.com/ qa@example.com
```

### Address tags (extension delimiters) as an alternative to aliases

Postfix supports so-called address tags, in the form of plus (+) tags - i.e. address+tag@example.com will end up at address@example.com.

This is configured by default and the (configurable !) separator is set to `+`.

For more info, see [How to use Address Tagging (user+tag@example.com) with Postfix](https://www.stevejenkins.com/blog/2011/03/how-to-use-address-tagging-usertagexample-com-with-postfix/) and the [official documentation](http://www.postfix.org/postconf.5.html#recipient_delimiter).

Note that if you do decide to change the configurable separator, you must add the same line to *both* `config/postfix-main.cf` and `config/dovecot.cf`, because Dovecot is acting as the delivery agent. For example, to switch to `-`, add:

```
recipient_delimiter = -
```
