---
title: 'Advanced | LDAP Authentication'
---

## Introduction

Getting started with ldap and `docker-mailserver` we need to take 3 parts in account:

- `postfix` for incoming & outgoing email
- `dovecot` for accessing mailboxes
- `saslauthd` for SMTP authentication (this can also be delegated to dovecot)

## Variables to Control Provisioning by the Container

Have a look at [the ENV page][docs-environment] for information on the default values.

### `LDAP_QUERY_FILTER_*`

Those variables contain the LDAP lookup filters for postfix, using `%s` as the placeholder for the domain or email address in question. This means that...

- ...for incoming email, the domain must return an entry for the `DOMAIN` filter (see [`virtual_alias_domains`](http://www.postfix.org/postconf.5.html#virtual_alias_domains)).
- ...for incoming email, the inboxes which receive the email are chosen by the `USER`, `ALIAS` and `GROUP` filters.
    - The `USER` filter specifies personal mailboxes, for which only one should exist per address, for example `(mail=%s)` (also see [`virtual_mailbox_maps`](http://www.postfix.org/postconf.5.html#virtual_mailbox_maps))
    - The `ALIAS` filter specifies aliases for mailboxes, using [`virtual_alias_maps`](http://www.postfix.org/postconf.5.html#virtual_alias_maps), for example `(mailAlias=%s)`
    - The `GROUP` filter specifies the personal mailboxes in a group (for emails that multiple people shall receive), using [`virtual_alias_maps`](http://www.postfix.org/postconf.5.html#virtual_alias_maps), for example `(mailGroupMember=%s)`
    - Technically, there is no difference between `ALIAS` and `GROUP`, but ideally you should use `ALIAS` for personal aliases for a singular person (like `ceo@example.org`) and `GROUP` for multiple people (like `hr@example.org`).
- ...for outgoing email, the sender address is put through the `SENDERS` filter, and only if the authenticated user is one of the returned entries, the email can be sent.
    - This only applies if `SPOOF_PROTECTION=1`.
    - If the `SENDERS` filter is missing, the `USER`, `ALIAS` and `GROUP` filters will be used in in a disjunction (OR).
    - To for example allow users from the `admin` group to spoof any sender email address, and to force everyone else to only use their personal mailbox address for outgoing email, you can use something like this: `(|(memberOf=cn=admin,*)(mail=%s))`

???+ example

    A really simple `LDAP_QUERY_FILTER` configuration, using only the _user filter_ and allowing only `admin@*` to spoof any sender addresses.

    ```yaml
    - ENABLE_LDAP=1
    - LDAP_SERVER_HOST=ldap.example.org
    - LDAP_SEARCH_BASE=dc=example,dc=org"
    - LDAP_BIND_DN=cn=admin,dc=example,dc=org
    - LDAP_BIND_PW=mypassword
    - SPOOF_PROTECTION=1
    
    - LDAP_QUERY_FILTER_DOMAIN=(mail=*@%s)
    - LDAP_QUERY_FILTER_USER=(mail=%s)
    - LDAP_QUERY_FILTER_ALIAS=(|) # doesn't match anything
    - LDAP_QUERY_FILTER_GROUP=(|) # doesn't match anything
    - LDAP_QUERY_FILTER_SENDERS=(|(mail=%s)(mail=admin@*))
    ```

### `DOVECOT_*_FILTER` & `DOVECOT_*_ATTRS`

These variables specify the LDAP filters that dovecot uses to determine if a user can log in to their IMAP account, and which mailbox is responsible to receive email for a specific postfix user.

This is split into the following two lookups, both using `%u` as the placeholder for the full login name ([see dovecot documentation for a full list of placeholders](https://doc.dovecot.org/configuration_manual/config_file/config_variables/)). Usually you only need to set `DOVECOT_USER_FILTER`, in which case it will be used for both filters.

- `DOVECOT_USER_FILTER` is used to get the account details (uid, gid, home directory, quota, ...) of a user.
- `DOVECOT_PASS_FILTER` is used to get the password information of the user, and is in pretty much all cases identical to `DOVECOT_USER_FILTER` (which is the default behaviour if left away).

If your directory doesn't have the [postfix-book schema](https://github.com/variablenix/ldap-mail-schema/blob/master/postfix-book.schema) installed, then you must change the internal attribute handling for dovecot. For this you have to change the `pass_attr` and the `user_attr` mapping, as shown in the example below:

```yaml
- DOVECOT_PASS_ATTRS=<YOUR_USER_IDENTIFIER_ATTRIBUTE>=user,<YOUR_USER_PASSWORD_ATTRIBUTE>=password
- DOVECOT_USER_ATTRS=<YOUR_USER_HOME_DIRECTORY_ATTRIBUTE>=home,<YOUR_USER_MAILSTORE_ATTRIBUTE>=mail,<YOUR_USER_MAIL_UID_ATTRIBUTE>=uid,<YOUR_USER_MAIL_GID_ATTRIBUTE>=gid
```

!!! note

    For `DOVECOT_*_ATTRS`, you can replace `ldapAttr=dovecotAttr` with `=dovecotAttr=%{ldap:ldapAttr}` for more flexibility, like for example `=home=/var/mail/%{ldap:uid}` or just `=uid=5000`.

    A list of dovecot attributes can be found [in the dovecot documentation](https://doc.dovecot.org/configuration_manual/authentication/user_databases_userdb/#authentication-user-database).

???+ example "Defaults"

    ```yaml
    - DOVECOT_USER_ATTRS=mailHomeDirectory=home,mailUidNumber=uid,mailGidNumber=gid,mailStorageDirectory=mail
    - DOVECOT_PASS_ATTRS=uniqueIdentifier=user,userPassword=password
    - DOVECOT_USER_FILTER=(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))
    ```

???+ example

    Setup for a directory that has the [qmail-schema](https://github.com/amery/qmail/blob/master/qmail.schema) installed and uses `uid`:

    ```yaml
    - DOVECOT_PASS_ATTRS=uid=user,userPassword=password
    - DOVECOT_USER_ATTRS=homeDirectory=home,qmailUID=uid,qmailGID=gid,mailMessageStore=mail
    - DOVECOT_USER_FILTER=(&(objectClass=qmailUser)(uid=%u)(accountStatus=active))
    ```

The LDAP server configuration for dovecot will be taken mostly from postfix, other options can be found in [the environment section in the docs][docs-environment].

### `DOVECOT_AUTH_BIND`

Set this to `yes` to enable authentication binds ([more details in the dovecot documentation](https://wiki.dovecot.org/AuthDatabase/LDAP/AuthBinds)). Currently, only DN lookup is supported without further changes to the configuration files, so this is only useful when you want to bind as a readonly user without the permission to read passwords.

### `SASLAUTHD_LDAP_FILTER`

This filter is used for `saslauthd`, which is called by postfix when someone is authenticating through SMTP (assuming that `SASLAUTHD_MECHANISMS=ldap` is being used). Note that you'll need to set up the LDAP server for saslauthd seperately from postfix.

The filter variables are explained in detail [in the `LDAP_SASLAUTHD` file](https://github.com/winlibs/cyrus-sasl/blob/master/saslauthd/LDAP_SASLAUTHD#L121), but unfortunately, this method doesn't really support domains right now - that means that `%U` is the only token that makes sense in this variable.

!!! note "When to use this and how to avoid it"

    Using a separate filter for SMTP authentication allows you to for example allow `noreply@example.org` to send email, but not log in to IMAP or receive email: `(&(mail=%U@example.org)(|(memberOf=cn=email,*)(mail=noreply@example.org)))`

    If you don't want to use a separate filter for SMTP authentication, you can set `SASLAUTHD_MECHANISMS=rimap` and `SASLAUTHD_MECH_OPTIONS=127.0.0.1` to authenticate against dovecot instead - this means that the `DOVECOT_USER_FILTER` and `DOVECOT_PASS_FILTER` will be used for SMTP authentication as well.

???+ example "Configure LDAP with `saslauthd`"

    ```yaml
    - ENABLE_SASLAUTHD=1
    - SASLAUTHD_MECHANISMS=ldap
    - SASLAUTHD_LDAP_FILTER=(mail=%U@example.org)
    ```

## Secure Connection with LDAPS or StartTLS

To enable LDAPS, all you need to do is to add the protocol to `LDAP_SERVER_HOST`, for example `ldaps://example.org:636`.

To enable LDAP over StartTLS (on port 389), you need to set the following environment variables instead (the **protocol must not be `ldaps://`** in this case!):

```yaml
- LDAP_START_TLS=yes
- DOVECOT_TLS=yes
- SASLAUTHD_LDAP_START_TLS=yes
```

## LDAP Setup Examples

???+ example "Basic Setup"

    ```yaml
    version: '3.8'
    services:
      mailserver:
        image: docker.io/mailserver/docker-mailserver:latest
        hostname: mail
        domainname: example.com
        container_name: mailserver

        ports:
          - "25:25"
          - "143:143"
          - "587:587"
          - "993:993"

        volumes:
          - ./docker-data/dms/mail-data/:/var/mail/
          - ./docker-data/dms/mail-state/:/var/mail-state/
          - ./docker-data/dms/mail-logs/:/var/log/mail/
          - ./docker-data/dms/config/:/tmp/docker-mailserver/
          - /etc/localtime:/etc/localtime:ro

        environment:
          - ENABLE_SPAMASSASSIN=1
          - ENABLE_CLAMAV=1
          - ENABLE_FAIL2BAN=1
          - ENABLE_POSTGREY=1

          # >>> Postfix LDAP Integration
          - ENABLE_LDAP=1
          - LDAP_SERVER_HOST=ldap.example.org
          - LDAP_BIND_DN=cn=admin,ou=users,dc=example,dc=org
          - LDAP_BIND_PW=mypassword
          - LDAP_SEARCH_BASE=dc=example,dc=org
          - LDAP_QUERY_FILTER_DOMAIN=(|(mail=*@%s)(mailAlias=*@%s)(mailGroupMember=*@%s))
          - LDAP_QUERY_FILTER_USER=(&(objectClass=inetOrgPerson)(mail=%s))
          - LDAP_QUERY_FILTER_ALIAS=(&(objectClass=inetOrgPerson)(mailAlias=%s))
          - LDAP_QUERY_FILTER_GROUP=(&(objectClass=inetOrgPerson)(mailGroupMember=%s))
          - LDAP_QUERY_FILTER_SENDERS=(&(objectClass=inetOrgPerson)(|(mail=%s)(mailAlias=%s)(mailGroupMember=%s)))
          - SPOOF_PROTECTION=1
          # <<< Postfix LDAP Integration

          # >>> Dovecot LDAP Integration
          - DOVECOT_USER_FILTER=(&(objectClass=inetOrgPerson)(mail=%u))
          - DOVECOT_PASS_ATTRS=uid=user,userPassword=password
          - DOVECOT_USER_ATTRS==home=/var/mail/%{ldap:uid},=mail=maildir:~/Maildir,uidNumber=uid,gidNumber=gid
          # <<< Dovecot LDAP Integration

          # >>> SASL LDAP Authentication
          - ENABLE_SASLAUTHD=1
          - SASLAUTHD_MECHANISMS=ldap
          - SASLAUTHD_LDAP_FILTER=(&(mail=%U@example.org)(objectClass=inetOrgPerson))
          # <<< SASL LDAP Authentication

          - ONE_DIR=1
          - DMS_DEBUG=0
          - SSL_TYPE=letsencrypt
          - PERMIT_DOCKER=host

        cap_add:
          - NET_ADMIN
    ```

??? example "Kopano / Zarafa"

    ```yaml
    version: '3.8'

    services:
      mailserver:
        image: docker.io/mailserver/docker-mailserver:latest
        hostname: mail
        domainname: example.com
        container_name: mailserver

        ports:
          - "25:25"
          - "143:143"
          - "587:587"
          - "993:993"

        volumes:
          - ./docker-data/dms/mail-data/:/var/mail/
          - ./docker-data/dms/mail-state/:/var/mail-state/
          - ./docker-data/dms/config/:/tmp/docker-mailserver/

        environment:
          # We are not using dovecot here
          - SMTP_ONLY=1
          - ENABLE_SPAMASSASSIN=1
          - ENABLE_CLAMAV=1
          - ENABLE_FAIL2BAN=1
          - ENABLE_POSTGREY=1
          - SASLAUTHD_PASSWD=

          # >>> SASL Authentication
          - ENABLE_SASLAUTHD=1
          - SASLAUTHD_LDAP_FILTER=(&(sAMAccountName=%U)(objectClass=person))
          - SASLAUTHD_MECHANISMS=ldap
          # <<< SASL Authentication

          # >>> Postfix Ldap Integration
          - ENABLE_LDAP=1
          - LDAP_SERVER_HOST=<yourLdapContainer/yourLdapServer>
          - LDAP_SEARCH_BASE=dc=mydomain,dc=loc
          - LDAP_BIND_DN=cn=Administrator,cn=Users,dc=mydomain,dc=loc
          - LDAP_BIND_PW=mypassword
          - LDAP_QUERY_FILTER_USER=(&(objectClass=user)(mail=%s))
          - LDAP_QUERY_FILTER_GROUP=(&(objectclass=group)(mail=%s))
          - LDAP_QUERY_FILTER_ALIAS=(&(objectClass=user)(otherMailbox=%s))
          - LDAP_QUERY_FILTER_DOMAIN=(&(|(mail=*@%s)(mailalias=*@%s)(mailGroupMember=*@%s))(mailEnabled=TRUE))
          # <<< Postfix Ldap Integration

          # >>> Kopano Integration
          - ENABLE_POSTFIX_VIRTUAL_TRANSPORT=1
          - POSTFIX_DAGENT=lmtp:kopano:2003
          # <<< Kopano Integration

          - ONE_DIR=1
          - DMS_DEBUG=0
          - SSL_TYPE=letsencrypt
          - PERMIT_DOCKER=host

        cap_add:
          - NET_ADMIN
    ```

[docs-environment]: ../environment.md
