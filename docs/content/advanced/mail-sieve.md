### User-defined sieve filters

[Sieve](http://sieve.info/) allows to specify filtering rules for incoming emails that allow for example sorting mails into different folders depending on the title of an email.

To specify a user-defined Sieve filter place a `.dovecot.sieve` file into a virtual user's mail folder e.g. `/var/mail/domain.com/user1/.dovecot.sieve`. If this file exists dovecot will apply the filtering rules.

It's even possible to install a user provided Sieve filter at startup during users setup: simply include a Sieve file in the `config `path for each user login that need a filter. The file name provided should be in the form **\<user_login\>.dovecot.sieve**, so for example for `user1@domain.tld` you should provide a Sieve file named `config/user1@domain.tld.dovecot.sieve`.

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


Another example of a sieve filter that forward mails to a different address:

```
require ["copy"];

redirect :copy "user2@otherdomain.tld";
```

For more examples or a detailed description of the Sieve language have a look at [the official site](http://sieve.info/examplescripts). Other resources are available on the internet where you can find several [examples](https://support.tigertech.net/sieve#sieve-example-rules-jmp).

### Manage Sieve

The [Manage Sieve](http://wiki1.dovecot.org/ManageSieve) extension allows users to modify their Sieve script by themselves. The authentication mechanisms are the same as for the main dovecot service. ManageSieve runs on port `4190` and needs to be enabled using the `ENABLE_MANAGESIEVE=1` environment variable.

```
(docker-compose.yml)
ports:
 - ...
 - "4190:4190"
environment:
 - ...
 - ENABLE_MANAGESIEVE=1
```

All user defined sieve scripts that are managed by ManageSieve are stored in the user's home folder in `/var/mail/domain.com/user1/sieve`. Just one sieve script might be active for a user and is sym-linked to `/var/mail/domain.com/user1/.dovecot.sieve` automatically.

***Note:*** ManageSieve makes sure to not overwrite an existing `.dovecot.sieve` file. If a user activates a new sieve script the old one is backuped and moved to the `sieve` folder.

The extension is known to work with the following ManageSieve clients:
 * Thunderbird with latest **Sieve** extension. If the extension doesn't work with the add-on available directly from within Thunderbird, try the developer build at https://github.com/thsmi/sieve.