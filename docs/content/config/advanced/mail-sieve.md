---
title: 'Advanced | Email Filtering with Sieve'
---

## User-Defined Sieve Filters

[Sieve](http://sieve.info/) allows to specify filtering rules for incoming emails that allow for example sorting mails into different folders depending on the title of an email.
There are global and user specific filters which are filtering the incoming emails in the following order:

- Global-before -> User specific -> Global-after

Global filters are applied to EVERY incoming mail for EVERY email address. 
To specify a global Sieve filter provide a `config/before.dovecot.sieve` or a `config/after.dovecot.sieve` file with your filter rules.
If any filter in this filtering chain discards an incoming mail, the delivery process will stop as well and the mail will not reach any following filters(e.g. global-before stops an incoming spam mail: The mail will get discarded and a user-specific filter won't get applied.)

To specify a user-defined Sieve filter place a `.dovecot.sieve` file into a virtual user's mail folder e.g. `/var/mail/domain.com/user1/.dovecot.sieve`. If this file exists dovecot will apply the filtering rules.

It's even possible to install a user provided Sieve filter at startup during users setup: simply include a Sieve file in the `config` path for each user login that need a filter. The file name provided should be in the form `<user_login>.dovecot.sieve`, so for example for `user1@domain.tld` you should provide a Sieve file named `config/user1@domain.tld.dovecot.sieve`.

An example of a sieve filter that moves mails to a folder `INBOX/spam` depending on the sender address:

!!! example

    ```sieve
    require ["fileinto", "reject"];

    if address :contains ["From"] "spam@spam.com" {
      fileinto "INBOX.spam";
    } else {
      keep;
    }
    ```

!!! warning
    That folders have to exist beforehand if sieve should move them.

Another example of a sieve filter that forward mails to a different address:

!!! example 

      ```sieve
      require ["copy"];

      redirect :copy "user2@otherdomain.tld";
      ```

Just forward all incoming emails and do not save them locally:

!!! example

    ```sieve
    redirect "user2@otherdomain.tld";
    ```

You can also use external programs to filter or pipe (process) messages by adding executable scripts in `config/sieve-pipe` or `config/sieve-filter`. This can be used in lieu of a local alias file, for instance to forward an email to a webservice. These programs can then be referenced by filename, by all users. Note that the process running the scripts run as a privileged user. For further information see [Dovecot's wiki](https://wiki.dovecot.org/Pigeonhole/Sieve/Plugins/Pipe).

```sieve
require ["vnd.dovecot.pipe"];
pipe "external-program";
```

For more examples or a detailed description of the Sieve language have a look at [the official site](http://sieve.info/examplescripts). Other resources are available on the internet where you can find several [examples](https://support.tigertech.net/sieve#sieve-example-rules-jmp).

## Manage Sieve

The [Manage Sieve](https://doc.dovecot.org/admin_manual/pigeonhole_managesieve_server/) extension allows users to modify their Sieve script by themselves. The authentication mechanisms are the same as for the main dovecot service. ManageSieve runs on port `4190` and needs to be enabled using the `ENABLE_MANAGESIEVE=1` environment variable.

!!! example

    ```yaml
    # docker-compose.yml
    ports:
      - "4190:4190"
    environment:
      - ENABLE_MANAGESIEVE=1
    ```

All user defined sieve scripts that are managed by ManageSieve are stored in the user's home folder in `/var/mail/domain.com/user1/sieve`. Just one sieve script might be active for a user and is sym-linked to `/var/mail/domain.com/user1/.dovecot.sieve` automatically.

!!! note
    ManageSieve makes sure to not overwrite an existing `.dovecot.sieve` file. If a user activates a new sieve script the old one is backuped and moved to the `sieve` folder.

The extension is known to work with the following ManageSieve clients:

- **Sieve Editor**  a portable standalone application based on the former Thunderbird plugin (https://github.com/thsmi/sieve).
