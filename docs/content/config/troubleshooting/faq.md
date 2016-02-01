### What kind of database are you using?
None. No *sql database required.  
This image is based on config files that can be versioned.  
You'll probably want to `push` your config updates to your server and restart the container to apply changes.  

### Where are emails stored?
Mails are stored in `/var/mail/${domain}/${username}`.  
You should use a data volume container for `/var/mail` for data persistence. Otherwise, your data may be lost.

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

### What about backups?

## Backups

Assuming that you use `docker-compose` and a data volume container named `maildata`, you can backup your user mails like this:

    docker run --rm \
    --volumes-from maildata_1 \
    -v "$(pwd)":/backups \
    -ti tvial/docker-mailserver \
    tar cvzf /backups/docker-mailserver-`date +%y%m%d-%H%M%S`.tgz /var/mail
