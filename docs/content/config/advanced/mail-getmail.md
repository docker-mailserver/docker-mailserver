---
title: 'Advanced | Email Gathering with Getmail'
---

To enable the [getmail][getmail-website] service to retrieve e-mails set the environment variable `ENABLE_GETMAIL` to `1`. Your `docker-compose.yml` file should look like following snippet:

```yaml
environment:
  - ENABLE_GETMAIL=1
  - GETMAIL_POLL=300
```

Generate a file called `getmail-<USER>.cf` and place it in the `docker-data/dms/config/` folder. Your `docker-mailserver` folder should look like this example:

```txt
├── docker-data/dms/config
│   ├── dovecot.cf
│   ├── getmail-<USER>.cf
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
message_log = /var/log/mail/getmail-PLACEHOLDER.log
```

to override these mount your own common settings to /etc/getmailrc_general

### IMAP Configuration 

!!! example
    ```getmailrc
    [retriever]
    type = SimpleIMAPRetriever
    server = imap.example.net
    username = fred.flintstone
    password = mailpassword

    [destination]
    type = MDA_external
    path = /usr/lib/dovecot/deliver
    allow_root_commands = true
    arguments =("-d","fred.flinstone@bedrock.com")
    ```

### POP3 Configuration 

!!! example
    ```getmailrc
    [retriever]
    type = SimplePOP3Retriever
    server = pop.example.net
    username = fred.flintstone
    password = mailpassword

    [destination]
    type = MDA_external
    path = /usr/lib/dovecot/deliver
    allow_root_commands = true
    arguments =("-d","fred.flinstone@bedrock.com")
    ```

### Polling Interval

By default the getmail service searches every 5 minutes for new mails on your external mail accounts. You can override this default value by changing the ENV variable `GETMAIL_POLL`:

```yaml
environment:
  - GETMAIL_POLL=60
```

You must specify a numeric argument which is a polling interval in seconds. The example above polls every minute for new mails.

[getmail-website]: https://www.getmail.org
[getmail-docs]: https://getmail6.org/configuration.html
[getmail-gmail-xoauth]: https://www.bytereef.org/howto/oauth2/getmail.html
