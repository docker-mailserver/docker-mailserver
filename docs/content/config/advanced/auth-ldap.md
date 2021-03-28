---
title: 'Advanced | LDAP Authentication'
---

## Introduction

Getting started with ldap and this mailserver we need to take 3 parts in account:

- `postfix`
- `dovecot`
- `saslauthd` (this can also be handled by dovecot)

## Variables to Control Provisioning by the Container

Have a look at the [`ENVIRONMENT.md`][github-file-env] for information on the default values.

!!! example "postfix"

    - `LDAP_QUERY_FILTER_USER`
    - `LDAP_QUERY_FILTER_GROUP`
    - `LDAP_QUERY_FILTER_ALIAS`
    - `LDAP_QUERY_FILTER_DOMAIN`

!!! example "saslauthd"

    - `SASLAUTHD_LDAP_FILTER`

!!! example "dovecot"

    - `DOVECOT_USER_FILTER`
    - `DOVECOT_PASS_FILTER`

## LDAP Setup - Kopano / Zarafa

???+ example "Example Code"

    ```yaml
    ---
    version: '2'

    services:
      mail:
        image: mailserver/docker-mailserver:latest
        hostname: mail
        domainname: domain.com
        container_name: mail

        ports:
          - "25:25"
          - "143:143"
          - "587:587"
          - "993:993"

        volumes:
          - maildata:/var/mail
          - mailstate:/var/mail-state
          - ./config/:/tmp/docker-mailserver/

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
          - SASLAUTHD_LDAP_SERVER=<yourLdapContainer/yourLdapServer>
          - SASLAUTHD_LDAP_PROTO=
          - SASLAUTHD_LDAP_BIND_DN=cn=Administrator,cn=Users,dc=mydomain,dc=loc
          - SASLAUTHD_LDAP_PASSWORD=mypassword
          - SASLAUTHD_LDAP_SEARCH_BASE=dc=mydomain,dc=loc
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

    volumes:
      maildata:
        driver: local
      mailstate:
        driver: local
    ```

If your directory has not the postfix-book schema installed, then you must change the internal attribute handling for dovecot. For this you have to change the `pass_attr` and the `user_attr` mapping, as shown in the example below:

```yaml
- DOVECOT_PASS_ATTR=<YOUR_USER_IDENTIFYER_ATTRIBUTE>=user,<YOUR_USER_PASSWORD_ATTRIBUTE>=password
- DOVECOT_USER_ATTR=<YOUR_USER_HOME_DIRECTORY_ATTRIBUTE>=home,<YOUR_USER_MAILSTORE_ATTRIBUTE>=mail,<YOUR_USER_MAIL_UID_ATTRIBUTE>=uid, <YOUR_USER_MAIL_GID_ATTRIBUTE>=gid
```

The following example illustrates this for a directory that has the qmail-schema installed and that uses `uid`:

```yaml
- DOVECOT_PASS_ATTRS=uid=user,userPassword=password
- DOVECOT_USER_ATTRS=homeDirectory=home,qmailUID=uid,qmailGID=gid,mailMessageStore=mail
- DOVECOT_PASS_FILTER=(&(objectClass=qmailUser)(uid=%u)(accountStatus=active))
- DOVECOT_USER_FILTER=(&(objectClass=qmailUser)(uid=%u)(accountStatus=active))
```

[github-file-env]: https://github.com/docker-mailserver/docker-mailserver/blob/master/ENVIRONMENT.md