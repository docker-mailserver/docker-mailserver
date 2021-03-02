---
title: 'Use Cases | Forward-Only Mailserver with LDAP'
---

## Building a Forward-Only Mailserver

A **forward-only** mailserver does not have any local mailboxes. Instead, it has only aliases that forward emails to external email accounts (for example to a gmail account). You can also send email from the localhost (the computer where the mailserver is installed), using as sender any of the alias addresses.

The important settings for this setup (on `mailserver.env`) are these:

```env
PERMIT_DOCKER=host
ENABLE_POP3=
ENABLE_CLAMAV=0
SMTP_ONLY=1
ENABLE_SPAMASSASSIN=0
ENABLE_FETCHMAIL=0
```

Since there are no local mailboxes, we use `SMTP_ONLY=1` to disable `dovecot`. We disable as well the other services that are related to local mailboxes (`POP3`, `ClamAV`, `SpamAssassin`, etc.)

We can create aliases with `./setup.sh`, like this:

```sh
./setup.sh alias add <alias-address> <external-email-account>
```

## Authenticating with LDAP

If you want to send emails from outside the mailserver you have to authenticate somehow (with a username and password). One way of doing it is described in [this discussion][github-issue-1247]. However if there are many user accounts, it is better to use authentication with LDAP. The settings for this on `mailserver.env` are:

```env
ENABLE_LDAP=1
LDAP_START_TLS=yes
LDAP_SERVER_HOST=ldap.example.org
LDAP_SEARCH_BASE=ou=users,dc=example,dc=org
LDAP_BIND_DN=cn=mailserver,dc=example,dc=org
LDAP_BIND_PW=pass1234

ENABLE_SASLAUTHD=1
SASLAUTHD_MECHANISMS=ldap
SASLAUTHD_LDAP_SERVER=ldap.example.org
SASLAUTHD_LDAP_SSL=0
SASLAUTHD_LDAP_START_TLS=yes
SASLAUTHD_LDAP_BIND_DN=cn=mailserver,dc=example,dc=org
SASLAUTHD_LDAP_PASSWORD=pass1234
SASLAUTHD_LDAP_SEARCH_BASE=ou=users,dc=example,dc=org
SASLAUTHD_LDAP_FILTER=(&(uid=%U)(objectClass=inetOrgPerson))
```

My LDAP data structure is very basic, containing only the username, password, and the external email address where to forward emails for this user. An entry looks like this

```properties
add uid=username,ou=users,dc=example,dc=org
uid: username
objectClass: inetOrgPerson
sn: username
cn: username
userPassword: {SSHA}abcdefghi123456789
email: real-email-address@external-domain.com
```

This structure is different from what is expected/assumed from the configuration scripts of the mailserver, so it doesn't work just by using the `LDAP_QUERY_FILTER_...` settings. Instead, I had to do [custom configuration][github-file-readme-patches]. I created the script `config/user-patches.sh`, with a content like this:

```bash
#!/bin/bash

rm -f /etc/postfix/{ldap-groups.cf,ldap-domains.cf}

postconf \
    "virtual_mailbox_domains = /etc/postfix/vhost" \
    "virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf texthash:/etc/postfix/virtual" \
    "smtpd_sender_login_maps = ldap:/etc/postfix/ldap-users.cf"

sed -i /etc/postfix/ldap-users.cf \
    -e '/query_filter/d' \
    -e '/result_attribute/d' \
    -e '/result_format/d'
cat <<EOF >> /etc/postfix/ldap-users.cf
query_filter = (uid=%u)
result_attribute = uid
result_format = %s@example.org
EOF

sed -i /etc/postfix/ldap-aliases.cf \
    -e '/domain/d' \
    -e '/query_filter/d' \
    -e '/result_attribute/d'
cat <<EOF >> /etc/postfix/ldap-aliases.cf
domain = example.org
query_filter = (uid=%u)
result_attribute = mail
EOF

postfix reload
```

You see that besides `query_filter`, I had to customize as well `result_attribute` and `result_format`.

!!! sealso

    For more details about using LDAP see: [LDAP managed mail server with Postfix and Dovecot for multiple domains](https://www.vennedey.net/resources/2-LDAP-managed-mail-server-with-Postfix-and-Dovecot-for-multiple-domains)

!!! seealso

    Another solution that serves as a forward-only mailserver is this: https://gitlab.com/docker-scripts/postfix

[github-file-readme-patches]: https://github.com/docker-mailserver/docker-mailserver/blob/master/README.md#custom-user-changes--patches
[github-issue-1247]: https://github.com/docker-mailserver/docker-mailserver/issues/1247
