# Pop3 Mail access

**docker-mailserver does  not think that it is  good idea to use pop.**

But is you really want to you have to add 3 lines to the docker-compose.yml :  
Add the ports 110 and 995 and add environment variable ENABLE_POP : 

```

maildata:
  image: ubuntu
  volumes:
    - /var/mail
  command: /bin/true

mail:
  image: "tvial/docker-mailserver"
  hostname: "mail"
  domainname: "domain.com"
  volumes_from:
   - maildata
  ports:
  - "25:25"
  - "143:143"
  - "587:587"
  - "993:993"
  - "110:110"
  - "995:995" 

  volumes:
  - ./spamassassin:/tmp/spamassassin/
  - ./postfix:/tmp/postfix/
  - ./opendkim/keys:/etc/opendkim/keys
  - ./letsencrypt/etc:/etc/letsencrypt
  environment:
  - DMS_SSL=letsencrypt
  - ENABLE_POP3=1


```
