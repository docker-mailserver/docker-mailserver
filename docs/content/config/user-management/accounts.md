Users (email accounts) are managed in `config/postfix-accounts.cf`.
Just add the full email address and its encrypted password separated by a pipe.

Example:

    user1@domain.tld|{SHA512-CRYPT}$6$2YpW1nYtPBs2yLYS$z.5PGH1OEzsHHNhl3gJrc3D.YMZkvKw/vp.r5WIiwya6z7P/CQ9GDEJDr2G2V0cAfjDFeAQPUoopsuWPXLk3u1
    user2@otherdomain.tld|{SHA512-CRYPT}$6$2YpW1nYtPBs2yLYS$z.5PGH1OEzsHHNhl3gJrc3D.YMZkvKw/vp.r5WIiwya6z7P/CQ9GDEJDr2G2V0cAfjDFeAQPUoopsuWPXLk3u1

In the previous example, we added 2 mail accounts for 2 different domains.
This is will automagically configure the mail-server as multi-domains.

To generate a new mail account entry in your configuration, you could run for example the following:

    docker run --rm \
      -e MAIL_USER=user1@domain.tld \
      -e MAIL_PASS=mypassword \
      -ti tvial/docker-mailserver:latest \
      /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf

You will be asked for a password. Just copy all the output string in the file `config/postfix-accounts.cf`.

The `doveadm pw` command let you choose between several encryption schemes for the password.
Use doveadm pw -l to get a list of the currently supported encryption schemes.

> Note: changes made with this script require a restart of the container. See [#552](../issues/552)

***
## Mailbox quota
**coming soon: https://github.com/tomav/docker-mailserver/pull/1469**

On top of the default quota (`POSTFIX_MAILBOX_SIZE_LIMIT`), you can define specific quotas per mailbox.
Quota implementation relies on [dovecot quota](https://wiki.dovecot.org/Quota/Configuration) which requires dovecot to be enabled. Consequently, quota directives are disabled when `SMTP_ONLY` is enabled.
<br>


A warning message will be sent to the user when his mailbox is reaching quota limit. Have a look at [90-quota.cf](https://github.com/tomav/docker-mailserver/tree/master/target/dovecot/90-quota.conf) for further details.

### Commands
_exec in the container_

- `setquota <user@domain.tld> [<quota>]`: define the quota of a mailbox (quota format e.g. 302M (B (byte), k (kilobyte), M (megabyte), G (gigabyte) or T (terabyte)))
- `delquota <user@domain.tld>`: delete the quota of a mailbox
- `doveadm quota get -u <user@domain>`: display the quota and the statistics of a mailbox

### `dovecot-quotas.cf`

This file is a key-value database where quotas are stored.

_dovecot-quotas.cf_
```
user@domain.tld:50M
john@other-domain.tld:1G
```
### Notes
- *imap-quota* is enabled and allow clients to query their mailbox usage.
- When the mailbox is deleted, the quota directive is deleted as well.
- LDAP ? Dovecot quotas supports LDAP **but it's not implemented** (_PR are welcome!_).