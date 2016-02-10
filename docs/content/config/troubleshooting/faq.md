### What kind of database are you using?
None. No *sql database required.  
This image is based on config files that can be versioned.  
You'll probably want to `push` your config updates to your server and restart the container to apply changes.  

### Where are emails stored?
Mails are stored in `/var/mail/${domain}/${username}`.  
You should use a [data volume container](https://medium.com/@ramangupta/why-docker-data-containers-are-good-589b3c6c749e#.uxyrp7xpu) for `/var/mail` to persist data. Otherwise, your data may be lost.

### How can I use data volume container as proposed above?

Here is a `docker-compose.yml` example which use a data volume container for email storage named `maildata`.

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
      volumes:
      - ./spamassassin:/tmp/spamassassin/
      - ./postfix:/tmp/postfix/
      - ./opendkim/keys:/etc/opendkim/keys
      - ./letsencrypt/etc:/etc/letsencrypt
      environment:
      - DMS_SSL=letsencrypt

### What about backups?

Assuming that you use `docker-compose` and a data volume container named `maildata`, you can backup your user mails like this:

    docker run --rm \
    --volumes-from maildata_1 \
    -v "$(pwd)":/backups \
    -ti tvial/docker-mailserver \
    tar cvzf /backups/docker-mailserver-`date +%y%m%d-%H%M%S`.tgz /var/mail

### How can I configure my email client?
Login are full email address (`user@domain.com`).  
Both login and password are managed in `postfix/accounts.cf` file.  
Please have a look to the `README` in order to manage users and aliases.  

    # imap
    username:           <user1@domain.tld>
    password:           <mypassword>
    server:             <mail.domain.tld>
    imap port:          143 or 993 with ssl (recommended)
    imap path prefix:   INBOX

    # smtp
    smtp port:          25 or 587 with ssl (recommended)
    username:           <user1@domain.tld>
    password:           <mypassword>

### How can I manage my custom Spamassassin rules?
Antispam rules are managed in `spamassassin/rules.cf`.  

### What kind of SSL certificates can I use?
You can use the same certificates you use with another mail server.  
The only thing is that we provide a `self-signed` certificate tool and a `letsencrypt` certificate loader.