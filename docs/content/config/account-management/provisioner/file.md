# User Management

## Accounts

Users (email accounts) are managed in `/tmp/docker-mailserver/postfix-accounts.cf`. The best way to manage accounts is to use the reliable `setup` command inside the container. Just run `docker exec <CONTAINER NAME> setup help` and have a look at the section about subcommands, specifically the `email` subcommand.

### Adding a new Account

#### Via `setup` inside the container

You can add an account by running `docker exec -ti <CONTAINER NAME> setup email add <NEW ADDRESS>`. This method is strongly preferred.

#### Manually

!!! warning

    This method is discouraged!

Alternatively, you may directly add the full email address and its encrypted password, separated by a pipe. To generate a new mail account data, directly from your host, you could for example run the following:

```sh
docker run --rm -it                                      \
  --env MAIL_USER=user1@example.com                      \
  --env MAIL_PASS=mypassword                             \
  ghcr.io/docker-mailserver/docker-mailserver:latest     \
  /bin/bash -c \
    'echo "${MAIL_USER}|$(doveadm pw -s SHA512-CRYPT -u ${MAIL_USER} -p ${MAIL_PASS})" >>docker-data/dms/config/postfix-accounts.cf'
```

You will then be asked for a password, and be given back the data for a new account entry, as text. To actually _add_ this new account, just copy all the output text in `docker-data/dms/config/postfix-accounts.cf` file of your running container.

The result could look like this:

```cf
user1@example.com|{SHA512-CRYPT}$6$2YpW1nYtPBs2yLYS$z.5PGH1OEzsHHNhl3gJrc3D.YMZkvKw/vp.r5WIiwya6z7P/CQ9GDEJDr2G2V0cAfjDFeAQPUoopsuWPXLk3u1
```

### Quotas

- `imap-quota` is enabled and allow clients to query their mailbox usage.
- When the mailbox is deleted, the quota directive is deleted as well.
- Dovecot quotas support LDAP, **but it's not implemented** (_PRs are welcome!_).

## Aliases

The best way to manage aliases is to use the reliable `setup` script inside the container. Just run `docker exec <CONTAINER NAME> setup help` and have a look at the section about subcommands, specifically the `alias`-subcommand.

### About

You may read [Postfix's documentation on virtual aliases][postfix-docs-alias] first. Aliases are managed in `/tmp/docker-mailserver/postfix-virtual.cf`. An alias is a full email address that will either be:

- delivered to an existing account registered in `/tmp/docker-mailserver/postfix-accounts.cf`
- redirected to one or more other email addresses

Alias and target are space separated. An example on a server with `example.com` as its domain:

```cf
# Alias delivered to an existing account
alias1@example.com user1@example.com

# Alias forwarded to an external email address
alias2@example.com external-account@gmail.com
```

### Configuring RegExp Aliases

Additional regexp aliases can be configured by placing them into `docker-data/dms/config/postfix-regexp.cf`. The regexp aliases get evaluated after the virtual aliases (container path: `/tmp/docker-mailserver/postfix-virtual.cf`). For example, the following `docker-data/dms/config/postfix-regexp.cf` causes all email sent to "test" users to be delivered to `qa@example.com` instead:

```cf
/^test[0-9][0-9]*@example.com/ qa@example.com
```

### Address Tags (Extension Delimiters) as an alternative to Aliases

Postfix supports so-called address tags, in the form of plus (+) tags - i.e. `address+tag@example.com` will end up at `address@example.com`. This is configured by default and the (configurable!) separator is set to `+`. For more info, see [Postfix's official documentation][postfix-docs-extension-delimiters].

!!! note

    If you do decide to change the configurable separator, you must add the same line to *both* `docker-data/dms/config/postfix-main.cf` and `docker-data/dms/config/dovecot.cf`, because Dovecot is acting as the delivery agent. For example, to switch to `-`, add:

    ```cf
    recipient_delimiter = -
    ```

[postfix-docs-alias]: http://www.postfix.org/VIRTUAL_README.html#virtual_alias
[postfix-docs-extension-delimiters]: http://www.postfix.org/postconf.5.html#recipient_delimiter
