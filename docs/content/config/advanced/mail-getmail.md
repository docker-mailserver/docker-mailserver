---
title: 'Advanced | Email Gathering with Getmail'
---

To enable the [getmail][getmail-website] service to retrieve e-mails set the environment variable `ENABLE_GETMAIL` to `1`. Your `compose.yaml` file should include the following:

```yaml
environment:
  - ENABLE_GETMAIL=1
  - GETMAIL_POLL=5
```

In your DMS config volume (eg: `docker-data/dms/config/`), create a `getmail-<ID>.cf` file for each remote account that you want to retrieve mail and store into a local DMS account. `<ID>` should be replaced by you, and is just the rest of the filename (eg: `getmail-example.cf`). The contents of each file should be configuration like documented below.

The directory structure should similar to this:

```txt
├── docker-data/dms/config
│   ├── dovecot.cf
│   ├── getmail-example.cf
│   ├── postfix-accounts.cf
│   └── postfix-virtual.cf
├── docker-compose.yml
└── README.md
```

## Configuration

A detailed description of the configuration options can be found in the [online version of the manual page][getmail-docs].

### Common Options

The default options added to each `getmail` config are:

```getmailrc
[options]
verbose = 0
read_all = false
delete = false
max_messages_per_session = 500
received = false
delivered_to = false
```

If you want to use a different base config, mount a file to `/etc/getmailrc_general`. This file will replace the default "Common Options" base config above, that all `getmail-<ID>.cf` files will extend with their configs when used.

??? example "IMAP Configuration" 

    This example will:

    1. Connect to the remote IMAP server from Gmail.
    2. Retrieve mail from the gmail account `alice` with password `notsecure`.
    3. Store any mail retrieved from the remote mail-server into DMS for the `user1@example.com` account that DMS manages.

    ```getmailrc
    [retriever]
    type = SimpleIMAPRetriever
    server = imap.gmail.com
    username = alice
    password = notsecure
    [destination]
    type = MDA_external
    path = /usr/lib/dovecot/deliver
    allow_root_commands = true
    arguments =("-d","user1@example.com")
    ```

??? example "POP3 Configuration"

    Just like the IMAP example above, but instead via POP3 protocol if you prefer that over IMAP.

    ```getmailrc
    [retriever]
    type = SimplePOP3Retriever
    server = pop3.gmail.com
    username = alice
    password = notsecure
    [destination]
    type = MDA_external
    path = /usr/lib/dovecot/deliver
    allow_root_commands = true
    arguments =("-d","user1@example.com")
    ```

### Polling Interval

By default the `getmail` service checks external mail accounts for new mail every 5 minutes. That polling interval is configurable via the `GETMAIL_POLL` ENV variable, with a value in minutes (_default: 5, min: 1, max: 30_):

```yaml
environment:
  - GETMAIL_POLL=1
```

### XOAUTH2 Authentication

It is possible to utilize the `getmail-gmail-xoauth-tokens` helper to provide authentication using `xoauth2` for [gmail (example 12)][getmail-docs-xoauth-12] or [Microsoft Office 365 (example 13)][getmail-docs-xoauth-13]

[getmail-website]: https://www.getmail.org
[getmail-docs]: https://getmail6.org/configuration.html
[getmail-docs-xoauth-12]: https://github.com/getmail6/getmail6/blob/1f95606156231f1e074ba62a9baa64f892a92ef8/docs/getmailrc-examples#L286
[getmail-docs-xoauth-13]: https://github.com/getmail6/getmail6/blob/1f95606156231f1e074ba62a9baa64f892a92ef8/docs/getmailrc-examples#L351
