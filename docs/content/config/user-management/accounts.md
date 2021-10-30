---
title: 'User Management | Accounts'
hide:
  - toc # Hide Table of Contents for this page
---

## Adding a New Account

Users (email accounts) are managed in `/tmp/docker-mailserver/postfix-accounts.cf`. **_The best way to manage accounts is to use the reliable [`setup.sh`][docs-setupsh] script_**. Or you may directly add the _full_ email address and its encrypted password, separated by a pipe:

```cf
user1@example.com|{SHA512-CRYPT}$6$2YpW1nYtPBs2yLYS$z.5PGH1OEzsHHNhl3gJrc3D.YMZkvKw/vp.r5WIiwya6z7P/CQ9GDEJDr2G2V0cAfjDFeAQPUoopsuWPXLk3u1
user2@not-example.com|{SHA512-CRYPT}$6$2YpW1nYtPBs2yLYS$z.5PGH1OEzsHHNhl3gJrc3D.YMZkvKw/vp.r5WIiwya6z7P/CQ9GDEJDr2G2V0cAfjDFeAQPUoopsuWPXLk3u1
```

In the example above, we've added 2 mail accounts for 2 different domains. Consequently, the mail-server will automatically be configured for multi-domains. Therefore, to generate a new mail account data, directly from your docker host, you could for example run the following:

```sh
docker run --rm \
  -e MAIL_USER=user1@example.com \
  -e MAIL_PASS=mypassword \
  -it mailserver/docker-mailserver:latest \
  /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER -p $MAIL_PASS)"' >> docker-data/dms/config/postfix-accounts.cf
```

You will then be asked for a password, and be given back the data for a new account entry, as text. To actually _add_ this new account, just copy all the output text in `docker-data/dms/config/postfix-accounts.cf` file of your running container.

!!! note

    `doveadm pw` command lets you choose between several encryption schemes for the password.

    Use `doveadm pw -l` to get a list of the currently supported encryption schemes.

!!! note

    Changes to the accounts list require a restart of the container, using `supervisord`. See [#552][github-issue-552].

---

### Notes

- `imap-quota` is enabled and allow clients to query their mailbox usage.
- When the mailbox is deleted, the quota directive is deleted as well.
- Dovecot quotas support LDAP, **but it's not implemented** (_PRs are welcome!_).

[docs-setupsh]: ../setup.sh.md
[github-issue-552]: https://github.com/docker-mailserver/docker-mailserver/issues/552
