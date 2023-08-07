---
title: 'Advanced | Email Gathering with Fetchmail'
---

To enable the [fetchmail][fetchmail-website] service to retrieve e-mails set the environment variable `ENABLE_FETCHMAIL` to `1`. Your `compose.yaml` file should look like following snippet:

```yaml
environment:
  - ENABLE_FETCHMAIL=1
  - FETCHMAIL_POLL=300
```

Generate a file called `fetchmail.cf` and place it in the `docker-data/dms/config/` folder. Your DMS folder should look like this example:

```txt
├── docker-data/dms/config
│   ├── dovecot.cf
│   ├── fetchmail.cf
│   ├── postfix-accounts.cf
│   └── postfix-virtual.cf
├── compose.yaml
└── README.md
```

## Configuration

A detailed description of the configuration options can be found in the [online version of the manual page][fetchmail-docs].

### IMAP Configuration

!!! example

    ```fetchmailrc
    poll 'imap.gmail.com' proto imap
      user 'username'
      pass 'secret'
      is 'user1@example.com'
      ssl
    ```

### POP3 Configuration

!!! example

    ```fetchmailrc
    poll 'pop3.gmail.com' proto pop3
      user 'username'
      pass 'secret'
      is 'user2@example.com'
      ssl
    ```

!!! caution

    Don’t forget the last line! (_eg: `is 'user1@example.com'`_). After `is`, you have to specify an email address from the configuration file: `docker-data/dms/config/postfix-accounts.cf`.

More details how to configure fetchmail can be found in the [fetchmail man page in the chapter “The run control file”][fetchmail-docs-run].

### Polling Interval

By default the fetchmail service searches every 5 minutes for new mails on your external mail accounts. You can override this default value by changing the ENV variable `FETCHMAIL_POLL`:

```yaml
environment:
  - FETCHMAIL_POLL=60
```

You must specify a numeric argument which is a polling interval in seconds. The example above polls every minute for new mails.

## Debugging

To debug your `fetchmail.cf` configuration run this command:

```sh
./setup.sh debug fetchmail
```

For more information about the configuration script `setup.sh` [read the corresponding docs][docs-setup].

Here a sample output of `./setup.sh debug fetchmail`:

```log
fetchmail: 6.3.26 querying outlook.office365.com (protocol POP3) at Mon Aug 29 22:11:09 2016: poll started
Trying to connect to 132.245.48.18/995...connected.
fetchmail: Server certificate:
fetchmail: Issuer Organization: Microsoft Corporation
fetchmail: Issuer CommonName: Microsoft IT SSL SHA2
fetchmail: Subject CommonName: outlook.com
fetchmail: Subject Alternative Name: outlook.com
fetchmail: Subject Alternative Name: *.outlook.com
fetchmail: Subject Alternative Name: office365.com
fetchmail: Subject Alternative Name: *.office365.com
fetchmail: Subject Alternative Name: *.live.com
fetchmail: Subject Alternative Name: *.internal.outlook.com
fetchmail: Subject Alternative Name: *.outlook.office365.com
fetchmail: Subject Alternative Name: outlook.office.com
fetchmail: Subject Alternative Name: attachment.outlook.office.net
fetchmail: Subject Alternative Name: attachment.outlook.officeppe.net
fetchmail: Subject Alternative Name: *.office.com
fetchmail: outlook.office365.com key fingerprint: 3A:A4:58:42:56:CD:BD:11:19:5B:CF:1E:85:16:8E:4D
fetchmail: POP3< +OK The Microsoft Exchange POP3 service is ready. [SABFADEAUABSADAAMQBDAEEAMAAwADAANwAuAGUAdQByAHAAcgBkADAAMQAuAHAAcgBvAGQALgBlAHgAYwBoAGEAbgBnAGUAbABhAGIAcwAuAGMAbwBtAA==]
fetchmail: POP3> CAPA
fetchmail: POP3< +OK
fetchmail: POP3< TOP
fetchmail: POP3< UIDL
fetchmail: POP3< SASL PLAIN
fetchmail: POP3< USER
fetchmail: POP3< .
fetchmail: POP3> USER user1@outlook.com
fetchmail: POP3< +OK
fetchmail: POP3> PASS *
fetchmail: POP3< +OK User successfully logged on.
fetchmail: POP3> STAT
fetchmail: POP3< +OK 0 0
fetchmail: No mail for user1@outlook.com at outlook.office365.com
fetchmail: POP3> QUIT
fetchmail: POP3< +OK Microsoft Exchange Server 2016 POP3 server signing off.
fetchmail: 6.3.26 querying outlook.office365.com (protocol POP3) at Mon Aug 29 22:11:11 2016: poll completed
fetchmail: normal termination, status 1
```

[docs-setup]: ../../config/setup.sh.md
[fetchmail-website]: https://www.fetchmail.info
[fetchmail-docs]: https://www.fetchmail.info/fetchmail-man.html
[fetchmail-docs-run]: https://www.fetchmail.info/fetchmail-man.html#31
