---
title: 'Advanced | Email Gathering with Getmail'
---

To enable the [getmail][getmail-website] service to retrieve e-mails set the environment variable `ENABLE_GETMAIL` to `1`. Your `docker-compose.yml` file should look like following snippet:

```yaml
environment:
  - ENABLE_GETMAIL=1
  - GETMAIL_POLL=5
```

Generate a file called `getmail-<ID>.cf` and place it in the `docker-data/dms/config/` folder. Your `docker-mailserver` folder should look like this example:

```txt
├── docker-data/dms/config
│   ├── dovecot.cf
│   ├── getmail-<ID>.cf
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

If you want to use different settings mount a filr to /etc/getmailrc_general, this will replace these so you must define all the options you want to use not just the changes.

### IMAP Configuration 

!!! example
    ```getmailrc
    [retriever]
    type = SimpleIMAPRetriever
    server = imap.gmail.com
    username = username
    password = secret

    [destination]
    type = MDA_external
    path = /usr/lib/dovecot/deliver
    allow_root_commands = true
    arguments =("-d","user1@example.com")
    ```

### POP3 Configuration 

!!! example
    ```getmailrc
    [retriever]
    type = SimplePOP3Retriever
    server = pop3.gmail.com
    username = username
    password = secret

    [destination]
    type = MDA_external
    path = /usr/lib/dovecot/deliver
    allow_root_commands = true
    arguments =("-d","user2@example.com")
    ```

### Polling Interval

By default the `getmail` service checks external mail accounts for new mail every 5 minutes. That polling interval is controlled by the `GETMAIL_POLL` ENV variable, with a value in seconds (default: 5, minimum: 1, maximum: 60):
```yaml
environment:
  - GETMAIL_POLL=1
```

[getmail-website]: https://www.getmail.org
[getmail-docs]: https://getmail6.org/configuration.html
[getmail-gmail-xoauth]: https://www.bytereef.org/howto/oauth2/getmail.html
