Please first read [Postfix documentation on virtual aliases](http://www.postfix.org/VIRTUAL_README.html#virtual_alias).

### Configuring aliases

Aliases are managed in `config/postfix-virtual.cf`.
An alias is a full email address that will be:
* delivered to an existing account in `config/postfix-accounts.cf`
* redirected to one or more other email addresses

Alias and target are space separated.

Example:

    # Alias to existing account
    alias1@domain.tld user1@domain.tld

    # Forward to external email address
    alias2@domain.tld external@gmail.com

### Configuring regexp aliases

Additional regexp aliases can be configured by placing them into `config/postfix-regexp.cf`. The regexp aliases get evaluated after the virtual aliases (postfix-virtual.cf). For example, the following `config/postfix-regexp.cf` causes all email to "test" users to be delivered to qa@example.com:

```
/^test[0-9][0-9]*@example.com/ qa@example.com
```

### Address tags as an alternative

Postfix supports address tags - i.e. address+tag@example.com will end up at address@example.com. This is configured by default and the (configurable) separator is set to `+`.

For more info, see [How to use Address Tagging (user+tag@example.com) with Postfix](https://www.stevejenkins.com/blog/2011/03/how-to-use-address-tagging-usertagexample-com-with-postfix/).