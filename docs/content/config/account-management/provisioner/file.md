---
title: 'Account Management | File Provisioner'
---

## Accounts

Users (email accounts) are managed in `/tmp/docker-mailserver/postfix-accounts.cf`.

The best way to manage accounts is to use our `setup` CLI provided inside the container.

!!! example "Using `setup` within the container"

    Try the following within the DMS container (`docker exec -it <CONTAINER NAME> bash`):

    - Add an account: `setup email add <NEW ADDRESS>`
    - Add an alias: `setup alias add <FROM ALIAS> <TO ADDRESS>`
    - Learn more about subcommands available: `setup help`

### Quotas

`/tmp/docker-mailserver/dovecot-quotas.cf`

- When the mailbox is deleted, the quota directive is deleted as well.

### Aliases

`/tmp/docker-mailserver/postfix-virtual.cf`

Alias and target are space separated. An example on a server with `example.com` as its domain:

```cf
# Alias delivered to an existing account
alias1@example.com user1@example.com

# Alias forwarded to an external email address
alias2@example.com external-account@gmail.com
```

Multiple recipients can be added to one alias, but is not officially supported.
https://github.com/orgs/docker-mailserver/discussions/3805#discussioncomment-8215417

### Configuring RegExp Aliases

- Additional regexp aliases can be configured by placing them into `docker-data/dms/config/postfix-regexp.cf`.
- The regexp aliases get evaluated after the virtual aliases (container path: `/tmp/docker-mailserver/postfix-virtual.cf`).

For example, the following `docker-data/dms/config/postfix-regexp.cf` causes all email sent to "test" users to be delivered to `qa@example.com` instead:

```cf
/^test[0-9][0-9]*@example.com/ qa@example.com
```
