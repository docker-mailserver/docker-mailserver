### What kind of database are you using?
None. No *sql database required.  
This image is based on config files that can be versioned.  
You'll probably want to `push` your config updates to your server and restart the container to apply changes.  

### What are the file format?

Of course file are Unix format with LF line endings.
Please do not use CRLF.

### Where are emails stored?
Mails are stored in `/var/mail/${domain}/${username}`.  
You should use a [data volume container](https://medium.com/@ramangupta/why-docker-data-containers-are-good-589b3c6c749e#.uxyrp7xpu) for `/var/mail` to persist data. Otherwise, your data may be lost.

### What about backups?

Assuming that you use `docker-compose` and a data volume container named `maildata`, you can backup your user mails like this:

    docker run --rm \
    --volumes-from maildata_1 \
    -v "$(pwd)":/backups \
    -ti tvial/docker-mailserver \
    tar cvzf /backups/docker-mailserver-`date +%y%m%d-%H%M%S`.tgz /var/mail

### How can I configure my email client?
Login are full email address (`user@domain.com`).  

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

Please use `STARTTLS`.

### How can I manage my custom Spamassassin rules?
Antispam rules are managed in `config/spamassassin-rules.cf`.

### How can I make Spamassassin learn spam?

Put received spams in `.Junk/` imap folder and add a cron like the fllowing:

```
# Everyday 2:00AM, learn spam for this specific user
0 2 * * * docker exec mail sa-learn --spam /var/mail/domain.com/username/.Junk
```

### What kind of SSL certificates can I use?
You can use the same certificates you use with another mail server.  
The only thing is that we provide a `self-signed` certificate tool and a `letsencrypt` certificate loader.

### I just moved from my old mail server but "it doesn't work".
If this migration implies a DNS modification, be sure to wait for DNS propagation before opening an issue.
Few examples of symptoms can be found [here](https://github.com/tomav/docker-mailserver/issues/95) or [here](https://github.com/tomav/docker-mailserver/issues/97).  
This could be related to a modification of your `MX` record, or the IP mapped to `mail.my-domain.tld`.

If everything is OK regarding DNS, please provide [formatted logs](https://guides.github.com/features/mastering-markdown/) and config files. This will allow us to help you.

If we're blind, we won't be able to do anything.

### Which system requirements needs my container to run `docker-mailserver` effectively?
1 core and 1GB of RAM is recommended, even it could work with 512M of RAM.