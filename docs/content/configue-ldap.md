**NOTE**: This page will provide several use cases like recipes to show, how this project can be used with it's LDAP Features.

### Ldap Setup - Kopano/Zarafa
```
---
version: '2'

services:
  mail:
    image: tvial/docker-mailserver:2.1
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