---
title: 'Tutorials | Basic Installation'
---

## A Basic Example With Relevant Environmental Variables

This example provides you only with a basic example of what a minimal setup could look like. We **strongly recommend** that you go through the configuration file yourself and adjust everything to your needs. The default [docker-compose.yml](https://github.com/docker-mailserver/docker-mailserver/blob/master/docker-compose.yml) can be used for the purpose out-of-the-box, see the [_Usage_ chapter](../../usage.md).

``` YAML
services:
  mailserver:
    image: ghcr.io/docker-mailserver/docker-mailserver:latest
    container_name: mailserver
    # Provide the FQDN of your mail server here (Your DNS MX record should point to this value)
    hostname: mail.example.com
    ports:
      - "25:25"
      - "465:465"
      - "587:587"
      - "993:993"
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/mail-state/:/var/mail-state/
      - ./docker-data/dms/mail-logs/:/var/log/mail/
      - ./docker-data/dms/config/:/tmp/docker-mailserver/
      - /etc/localtime:/etc/localtime:ro
    environment:
      - ENABLE_RSPAMD=1
      - ENABLE_CLAMAV=1
      - ENABLE_FAIL2BAN=1
    cap_add:
      - NET_ADMIN # For Fail2Ban to work
    restart: always
```

## A Basic LDAP Setup

**Note** There are currently no LDAP maintainers. If you encounter issues, please raise them in the issue tracker, but be aware that the core maintainers team will most likely not be able to help you. **We would appreciate and we encourage everyone to actively participate in maintaining LDAP-related code by becoming a maintainer!**

``` YAML
services:
  mailserver:
    image: ghcr.io/docker-mailserver/docker-mailserver:latest
    container_name: mailserver
    # Provide the FQDN of your mail server here (Your DNS MX record should point to this value)
    hostname: mail.example.com
    ports:
      - "25:25"
      - "465:465"
      - "587:587"
      - "993:993"
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/mail-state/:/var/mail-state/
      - ./docker-data/dms/mail-logs/:/var/log/mail/
      - ./docker-data/dms/config/:/tmp/docker-mailserver/
      - /etc/localtime:/etc/localtime:ro
    environment:
      - ACCOUNT_PROVISIONER=LDAP
      - LDAP_SERVER_HOST=ldap # your ldap container/IP/ServerName
      - LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain
      - LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain
      - LDAP_BIND_PW=admin
      - LDAP_QUERY_FILTER_USER=(&(mail=%s)(mailEnabled=TRUE))
      - LDAP_QUERY_FILTER_GROUP=(&(mailGroupMember=%s)(mailEnabled=TRUE))
      - LDAP_QUERY_FILTER_ALIAS=(|(&(mailAlias=%s)(objectClass=PostfixBookMailForward))(&(mailAlias=%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE)))
      - LDAP_QUERY_FILTER_DOMAIN=(|(&(mail=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailGroupMember=*@%s)(objectClass=PostfixBookMailAccount)(mailEnabled=TRUE))(&(mailalias=*@%s)(objectClass=PostfixBookMailForward)))
      - DOVECOT_PASS_FILTER=(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))
      - DOVECOT_USER_FILTER=(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))
      - ENABLE_SASLAUTHD=1
      - SASLAUTHD_MECHANISMS=ldap
      - SASLAUTHD_LDAP_SERVER=ldap
      - SASLAUTHD_LDAP_BIND_DN=cn=admin,dc=localhost,dc=localdomain
      - SASLAUTHD_LDAP_PASSWORD=admin
      - SASLAUTHD_LDAP_SEARCH_BASE=ou=people,dc=localhost,dc=localdomain
      - SASLAUTHD_LDAP_FILTER=(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%U))
      - POSTMASTER_ADDRESS=postmaster@localhost.localdomain
    restart: always
```
