### What kind of database are you using?
None. No *sql database required.  
This image is based on config files that can be versioned.  
You'll probably want to `push` your config updates to your server and restart the container to apply changes.  

### How can I sync container with host date/time?

Share the host `/etc/localtime` using:  

```
    volumes:
      - /etc/localtime:/etc/localtime:ro
```

### What is the file format?

All files are using the Unix format with `LF` line endings.
Please do not use `CRLF`.

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

### Why are Spamassassin x-headers not inserted into my sample.domain.com subdomain emails?

In the default setup, amavis only applies Spamassassin x-headers into domains matching the template listed in the config  file 05-domain_id (in the amavis defaults). The default setup @local_domains_acl = ( ".$mydomain" ); does not match subdomains. To match subdomains, you can override the @local_domains_acl directive in the amavis user config file 50-user with @local_domains_maps = ("."); to match any sort of domain template. 

### How can I make Spamassassin learn spam?

Put received spams in `.Junk/` imap folder and add a cron like the following:

```
# Everyday 2:00AM, learn spam for this specific user
# This assumes you're having `ONE_DIR=1` (consolidated in `/var/mail-state`)
0 2 * * * docker exec mail sa-learn --spam /var/mail/domain.com/username/.Junk --dbpath /var/mail-state/lib-amavis/.spamassassin
```

With the default settings, Spamassassin will require 200 mails trained for spam (for example with the method explained above) and 200 mails trained for ham (using the same command as above but using `--ham` and providing it with some ham mails). Until you provided these 200+200 mails, Spamassasin will not take the learned mails into account. For future reference, see the [Spamassassin Wiki](https://wiki.apache.org/spamassassin/BayesNotWorking).

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

### Is `docker-mailserver` running in a [rancher environment](http://rancher.com/rancher/)?

Yes, by Adding the Environment Variable `PERMIT_DOCKER: network`.

### Common errors

```
warning: connect to Milter service inet:localhost:8893: Connection refused
# DMARC not running
# => /etc/init.d/opendmarc restart

warning: connect to Milter service inet:localhost:8891: Connection refused
# DKIM not running
# => /etc/init.d/opendkim restart
```