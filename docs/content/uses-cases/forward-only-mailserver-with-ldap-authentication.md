# Forward-Only mailserver with LDAP authentication

## Building a Forward-Only mailserver

A **forward-only** mailserver does not have any local mailboxes. Instead, it has only aliases that forward emails to external email accounts (for example to a gmail account). You can also send email from the localhost (the computer where the mailserver is installed), using as sender any of the alias addresses.

The important settings for this setup (on `mailserver.env`) are these:

```
PERMIT_DOCKER=host
ENABLE_POP3=
ENABLE_CLAMAV=0
SMTP_ONLY=1
ENABLE_SPAMASSASSIN=0
ENABLE_FETCHMAIL=0
```

Since there are no local mailboxes, we use `SMTP_ONLY=1` to disable `dovecot`. We disable as well the other services that are related to local mailboxes (`POP3`, `ClamAV`, `SpamAssassin`, etc.)

We can create aliases with `./setup.sh`, like this:

```
./setup.sh alias add <alias-address> <external-email-account>
```

## Authenticating with LDAP
