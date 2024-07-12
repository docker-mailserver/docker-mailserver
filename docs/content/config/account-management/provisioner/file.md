---
title: 'Account Management | Provisioner (File)'
---

## Accounts

**Config file:** `docker-data/dms/config/postfix-accounts.cf`

The best way to manage DMS accounts and related config files is through our `setup` CLI provided within the container.

!!! example "Using the `setup` CLI"

    Try the following within the DMS container (`docker exec -it <CONTAINER NAME> bash`):

    - Add an account: `setup email add <EMAIL ADDRESS>`
    - Add an alias: `setup alias add <FROM ALIAS> <TO TARGET ADDRESS>`
    - Learn more about the available subcommands via: `setup help`

    ```bash
    # Starts a basic DMS instance and then shells into the container to use the `setup` CLI:
    docker run --rm -itd --name dms --hostname mail.example.com ghcr.io/docker-mailserver/docker-mailserver:latest
    docker exec -it dms bash

    # Create some accounts:
    setup email add john.doe@example.com bad-password
    setup email add jane.doe@example.com bad-password

    # Create an alias:
    setup alias add your-alias-here@example.com john.doe@example.com
    ```

!!! info

    Account creation will normalize the provided email address to lowercase, as DMS does not support multiple case-sensitive address variants.

    The email address chosen will also represent the _login username_ credential for mail clients to authenticate with.

## Quotas

**Config file:** `docker-data/dms/config/dovecot-quotas.cf`

When the mailbox is deleted, the quota directive is deleted as well.

## Aliases

**Config file:** `docker-data/dms/config/postfix-virtual.cf`

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
