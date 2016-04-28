### User-defined sieve filters

[Sieve](http://sieve.info/) allows to specify filtering rules for incoming emails that allow for example sorting mails into different folders depending on the title of an email.

To specify a user-defined Sieve filter place a `.dovecot.sieve` file into a virtual user's mail folder e.g. `/var/mail/domain.com/user1/.dovecot.sieve`. If this file exists dovecot will apply the filtering rules.

An example of a sieve filter that moves mails to a folder `INBOX/spam` depending on the sender address:

```
require ["fileinto", "reject"];

if address :contains ["From"] "spam@spam.com" {
   fileinto "INBOX.spam";
} else {
     keep;
}
```

***Note:*** that folders have to exist beforehand if sieve should move them.

For more examples or a detailed description of the Sieve language have a look at [the official site](http://sieve.info/examplescripts).