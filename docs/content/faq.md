---
title: 'FAQ'
---

### What kind of database are you using?

None! No database is required. The filesystem is the database. This image is based on config files that can be persisted using bind mounts (default) or Docker volumes, and as such versioned, backed up and so forth.

### Where are emails stored?

Mails are stored in `/var/mail/${domain}/${username}`. Since `v9.0.0` it is possible to add custom `user_attributes` for each accounts to have a different mailbox configuration (See [#1792][github-issue-1792]).

### How are IMAP mailboxes (_aka IMAP Folders_) set up?

`INBOX` is setup by default with the special IMAP folders `Drafts`, `Sent`, `Junk` and `Trash`. You can learn how to modify or add your own folders (_including additional special folders like `Archive`_) by visiting our docs page [_Customizing IMAP Folders_](../examples/use-cases/imap-folders) for more information.

### How do I update DMS?

**Make sure to read the [CHANGELOG](https://github.com/docker-mailserver/docker-mailserver/blob/master/CHANGELOG.md)** before updating to new versions, to be prepared for possible breaking changes.

Then, run the following commands:

``` BASH
docker compose pull
docker compose down
docker compose up -d
```

You should see the new version number on startup, for example: `[   INF   ]  Welcome to docker-mailserver 11.3.1`. And you're done! Don't forget to have a look at the remaining functions of the `setup.sh` script with `./setup.sh help`.

### Which operating systems are supported?

- Linux is officially supported.
- Windows and macOS are _not_ supported and users and have reported various issues running the image on these hosts.

As you'll realistically be deploying to production on a Linux host, if you are on Windows or macOS and want to run the image locally first, it's advised to do so via a VM guest running Linux if you have issues running DMS on your host system.

### What are the system requirements?

#### Recommended

- 1 vCore
- 2GB RAM
- Swap enabled for the container

#### Minimum

- 1 vCore
- 512MB RAM
- You'll need to avoid running some services like ClamAV (_disabled by default_) to be able to run on a host with 512MB of RAM.

!!! warning

    ClamAV can consume a lot of memory, as it reads the entire signature database into RAM.

    Current figure is about 850M and growing. If you get errors about ClamAV or amavis failing to allocate memory you need more RAM or more swap and of course docker must be allowed to use swap (not always the case). If you can't use swap at all you may need 3G RAM.

### How to alter a running DMS instance _without_ relaunching the container?

DMS aggregates multiple "sub-services", such as Postfix, Dovecot, Fail2ban, SpamAssassin, etc. In many cases, one may edit a sub-service's config and reload that very sub-service, without stopping and relaunching the whole mail server.

In order to do so, you'll probably want to push your config updates to your server through a Docker volume (these docs use: `./docker-data/dms/config/:/tmp/docker-mailserver/`), then restart the sub-service to apply your changes, using `supervisorctl`. For instance, after editing fail2ban's config: `supervisorctl restart fail2ban`.

See the [documentation for `supervisorctl`](http://supervisord.org/running.html#running-supervisorctl).

!!! tip
    To add, update or delete an email account; there is no need to restart postfix / dovecot service inside the container after using `setup.sh` script.

    For more information, see [#1639][github-issue-1639].

### How can I sync the container and host date/time?

Share the host's [`/etc/localtime`](https://www.freedesktop.org/software/systemd/man/localtime.html) with the container, e.g. by using a bind mount:

```yaml
volumes:
  - /etc/localtime:/etc/localtime:ro
```

Optionally, you can set the `TZ` ENV variable; e.g. `TZ=Europe/Berlin`. Check [this list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for which values are allowed.

### What is the file format?

All files are using the Unix format with `LF` line endings. Please do not use `CRLF`.

### Do you support multiple domains?

DMS supports multiple domains out of the box, so you can do this:

``` BASH
./setup.sh email add user1@example.com
./setup.sh email add user1@example.de
./setup.sh email add user1@server.example.org
```

### What about backups?

#### Bind mounts (default)

From the location of your `compose.yaml`, create a compressed archive of your `docker-data/dms/config/` and `docker-data/dms/mail-*` folders:

```bash
tar --gzip -cf "backup-$(date +%F).tar.gz" ./docker-data/dms
```

Then to restore `docker-data/dms/config/` and `docker-data/dms/mail-*` folders from your backup file:

```bash
tar --gzip -xf backup-date.tar.gz
```

#### Volumes

Assuming that you use `docker-compose` and data volumes, you can backup the configuration, emails and logs like this:

```sh
# create backup
docker run --rm -it \
  -v "${PWD}/docker-data/dms/config/:/tmp/docker-mailserver/" \
  -v "${PWD}/docker-data/dms-backups/:/backup/" \
  --volumes-from mailserver \
  alpine:latest \
  tar czf "/backup/mail-$(date +%F).tar.gz" /var/mail /var/mail-state /var/log/mail /tmp/docker-mailserver

# delete backups older than 30 days
find "${PWD}/docker-data/dms-backups/" -type f -mtime +30 -delete
```

### I Want to Know More About the Ports

See [this part of the documentation](../config/security/understanding-the-ports/) for further details and best practice advice, **especially regarding security concerns**.

### How can I configure my email client?

Login is full email address (`<user>@<domain>`).

```properties
# IMAP
username:           <user1@example.com>
password:           <mypassword>
server:             <mail.example.com>
imap port:          143 or 993 with STARTTLS/SSL (recommended)
imap path prefix:   INBOX

# SMTP
smtp port:          587 or 465 with STARTTLS/SSL (recommended)
username:           <user1@example.com>
password:           <mypassword>
```

DMS is properly configured for port 587, if possible, we recommend using port 465 for SMTP though. See [this section to learn more about ports](#i-want-to-know-more-about-the-ports).

### Can I use a naked/bare domain (i.e. no hostname)?

Yes, but not without some configuration changes. Normally it is assumed that DMS runs on a host with a name, so the fully qualified host name might be `mail.example.com` with the domain `example.com`. The MX records point to `mail.example.com`.

To use a bare domain (_where the host name is `example.com` and the domain is also `example.com`_), change `mydestination`:

- From: `mydestination = $myhostname, localhost.$mydomain, localhost`
- To: `mydestination = localhost.$mydomain, localhost`

Add the latter line to `docker-data/dms/config/postfix-main.cf`. If that doesn't work, make sure that [`OVERRIDE_HOSTNAME` is blank in your `mailserver.env` file][github-comment-override-hostname]. Without these changes there will be warnings in the logs like:

```log
warning: do not list domain example.com in BOTH mydestination and virtual_mailbox_domains
```

Plus of course mail delivery fails.

Also you need to define `hostname: example.com` in your `compose.yaml`.

!!! tip "You might not want a bare domain"

    We encourage you to consider using a subdomain where possible.

    - There are [benefits][github-comment-baredomain] to preferring a subdomain.
    - A bare domain is not required to have `user@example.com`, that is distinct from your hostname which is identified by a DNS MX record.

### How can I configure a catch-all?

Considering you want to redirect all incoming e-mails for the domain `example.com` to `user1@example.com`, add the following line to `docker-data/dms/config/postfix-virtual.cf`:

```cf
@example.com user1@example.com
```

### How can I delete all the emails for a specific user?

First of all, create a special alias named `devnull` by editing `docker-data/dms/config/postfix-aliases.cf`:

```cf
devnull: /dev/null
```

Considering you want to delete all the e-mails received for `baduser@example.com`, add the following line to `docker-data/dms/config/postfix-virtual.cf`:

```cf
baduser@example.com devnull
```

!!! important

    If you use a catch-all rule for the main/sub domain, you need another entry in `docker-data/dms/config/postfix-virtual.cf`:

    ```cf
    @mail.example.com hello@example.com
    baduser@example.com devnull
    devnull@mail.example.com devnull
    ```

### What kind of SSL certificates can I use?

Both RSA and ECDSA certs are supported. You can provide your own cert files manually, or mount a `letsencrypt` generated directory (_with alternative support for Traefik's `acme.json`_). Check out the [`SSL_TYPE` documentation](../config/environment/#ssl_type) for more details.

### I just moved from my old mail server to DMS, but "it doesn't work"?

If this migration implies a DNS modification, be sure to wait for DNS propagation before opening an issue.
Few examples of symptoms can be found [here][github-issue-95] or [here][github-issue-97].

This could be related to a modification of your `MX` record, or the IP mapped to `mail.example.com`. Additionally, [validate your DNS configuration](https://intodns.com/).

If everything is OK regarding DNS, please provide [formatted logs](https://guides.github.com/features/mastering-markdown/) and config files. This will allow us to help you.

If we're blind, we won't be able to do anything.

### Connection refused or No response at all

You see errors like "Connection Refused" and "Connection closed by foreign host", or you cannot connect at all? You may not be able to connect with your mail client (MUA)? Make sure to check Fail2Ban did not ban you (for exceeding the number of tried logins for example)! You can run

```bash
docker exec <CONTAINER NAME> setup fail2ban
```

and check whether your IP address appears. Use

```bash
docker exec <CONTAINER NAME> setup fail2ban unban <YOUR IP>
```

to unban the IP address.

### How can I authenticate users with `SMTP_ONLY=1`?

See [#1247][github-issue-1247] for an example.

!!! todo

    Write a How-to / Use-Case / Tutorial about authentication with `SMTP_ONLY`.

### Common Errors

#### Creating an alias or account with an address for `hostname`

Normally you will assign DMS a `hostname` such as `mail.example.com`. If you instead use a bare domain (_such as `example.com`_) or add an alias / account with the same value as your `hostname`, this can cause a conflict for mail addressed to `@hostname` as Postfix gets confused where to deliver the mail (_`hostname` is configured for only system accounts via the Postfix `main.cf` setting `mydestination`_).

When this conflict is detected you'll find logs similar to this:

```log
warning: do not list domain mail.example.com in BOTH mydestination and virtual_mailbox_domains
...
NOQUEUE: reject: RCPT from HOST[IP]: 550 5.1.1 <RECIPIENT>: Recipient address rejected: User unknown in local recipient table; ...
```

Opt-out of mail being directed to services by excluding `$myhostname` as a destination with a [`postfix-main.cf`][docs-override-postfix] override config:

```cf
mydestination = localhost.$mydomain, localhost
```

!!! tip

    You may want to configure a `postmaster` alias via `setup alias add` to receive system notifications.

!!! warning

    Internal mail destined for `root`, `amavis` or other accounts will now no longer be received without an alias or account created for them.

### How to use DMS behind a proxy

[Using `user-patches.sh`][docs-userpatches], update the container file `/etc/postfix/main.cf` to include:

```cf
proxy_interfaces = X.X.X.X (your public IP)
```

### How to adjust settings with the `user-patches.sh` script

Suppose you want to change a number of settings that are not listed as variables or add things to the server that are not included?

DMS has a built-in way to do post-install processes. If you place a script called **`user-patches.sh`** in the config directory it will be run after all configuration files are set up, but before the postfix, amavis and other daemons are started.

It is common to use a local directory for config added to `docker-mailsever` via a volume mount in your `compose.yaml` (eg: `./docker-data/dms/config/:/tmp/docker-mailserver/`).

Add or create the script file to your config directory:

```sh
cd ./docker-data/dms/config
touch user-patches.sh
chmod +x user-patches.sh
```

Then fill `user-patches.sh` with suitable code.

If you want to test it you can move into the running container, run it and see if it does what you want. For instance:

```sh
# start shell in container
./setup.sh debug login

# check the file
cat /tmp/docker-mailserver/user-patches.sh

# run the script
/tmp/docker-mailserver/user-patches.sh

# exit the container shell back to the host shell
exit
```

You can do a lot of things with such a script. You can find an example `user-patches.sh` script here: [example `user-patches.sh` script][hanscees-userpatches].

We also have a [very similar docs page][docs-userpatches] specifically about this feature!

!!! attention "Special use-case - patching the `supervisord` configuration"

    It seems worth noting, that the `user-patches.sh` gets executed through `supervisord`. If you need to patch some supervisord config (e.g. `/etc/supervisor/conf.d/saslauth.conf`), the patching happens too late.

    An easy workaround is to make the `user-patches.sh` reload the supervisord config after patching it:

    ```bash
    #!/bin/bash
    sed -i 's/rimap -r/rimap/' /etc/supervisor/conf.d/saslauth.conf
    supervisorctl update
    ```

### How to ban custom IP addresses with Fail2ban

Use the following command:

```bash
./setup.sh fail2ban ban <IP>
```

The default bantime is 180 days. This value can be [customized][fail2ban-customize].

### What to do in case of SPF/Forwarding problems

If you got any problems with SPF and/or forwarding mails, give [SRS](https://github.com/roehling/postsrsd/blob/master/README.rst) a try. You enable SRS by setting `ENABLE_SRS=1`. See the variable description for further information.

### Why are my emails not being delivered?

There are many reasons why email might be rejected, common causes are:

- Wrong or untrustworthy SSL certificate.
- A TLD (your domain) or IP address with a bad reputation.
- Misconfigured DNS records.

DMS does not manage those concerns, verify they are not causing your delivery problems before reporting a bug on our issue tracker. Resources that can help you troubleshoot:

- [mail-tester](https://www.mail-tester.com/) can test your deliverability.
- [helloinbox](https://www.helloinbox.email/) provides a checklist of things to improve your deliverability.

### Special Directories

#### What About the `docker-data/dms/config/` Directory?

This documentation and all example configuration files in the GitHub repository use `docker-data/dms/config/` to refer to the directory in the host that is mounted (e.g. via a bind mount) to `/tmp/docker-mailserver/` inside the container.

Most configuration files for Postfix, Dovecot, etc. are persisted here. [Optional configuration][docs-optional-configuration] is stored here as well.

#### What About the `docker-data/dms/mail-state/` Directory?

This documentation and all example configuration files in the GitHub repository use `docker-data/dms/mail-state/` to refer to the directory in the host that is mounted (e.g. via a bind mount) to `/var/mail-state/` inside the container.

When you run DMS with the ENV variable `ONE_DIR=1` (default), this directory will provide support to persist Fail2Ban blocks, ClamAV signature updates, and the like when the container is restarted or recreated. Service data is [relocated to the `mail-state` folder][mail-state-folders] for the following services: Postfix, Dovecot, Fail2Ban, Amavis, PostGrey, ClamAV, SpamAssassin, Rspamd & Redis.

### SpamAssasin

#### How can I manage my custom SpamAssassin rules?

Antispam rules are managed in `docker-data/dms/config/spamassassin-rules.cf`.

#### What are acceptable `SA_SPAM_SUBJECT` values?

For no subject set `SA_SPAM_SUBJECT=undef`.

For a trailing white-space subject one can define the whole variable with quotes in `compose.yaml`:

```yaml
environment:
  - "SA_SPAM_SUBJECT=[SPAM] "
```

#### Why are SpamAssassin `x-headers` not inserted into my `subdomain.example.com` subdomain emails?

In the default setup, amavis only applies SpamAssassin x-headers into domains matching the template listed in the config file (`05-domain_id` in the amavis defaults).

The default setup `@local_domains_acl = ( ".$mydomain" );` does not match subdomains. To match subdomains, you can override the `@local_domains_acl` directive in the amavis user config file `50-user` with `@local_domains_maps = (".");` to match any sort of domain template.

#### How can I make SpamAssassin better recognize spam?

Put received spams in `.Junk/` imap folder using `SPAMASSASSIN_SPAM_TO_INBOX=1` and `MOVE_SPAM_TO_JUNK=1` and add a _user_ cron like the following:

```conf
# This assumes you're having `environment: ONE_DIR=1` in the `mailserver.env`,
# with a consolidated config in `/var/mail-state`
#
# m h dom mon dow command
# Everyday 2:00AM, learn spam from a specific user
0 2 * * * docker exec mailserver sa-learn --spam /var/mail/example.com/username/.Junk --dbpath /var/mail-state/lib-amavis/.spamassassin
```

With `docker-compose` you can more easily use the internal instance of `cron` within DMS. This is less problematic than the simple solution shown above, because it decouples the learning from the host on which DMS is running, and avoids errors if the mail server is not running.

The following configuration works nicely:

??? example

    Create a _system_ cron file:

    ```sh
    # in the compose.yaml root directory
    mkdir -p ./docker-data/dms/cron
    touch ./docker-data/dms/cron/sa-learn
    chown root:root ./docker-data/dms/cron/sa-learn
    chmod 0644 ./docker-data/dms/cron/sa-learn
    ```

    Edit the system cron file `nano ./docker-data/dms/cron/sa-learn`, and set an appropriate configuration:

    ```conf
    # This assumes you're having `environment: ONE_DIR=1` in the env-mailserver,
    # with a consolidated config in `/var/mail-state`
    #
    # '> /dev/null' to send error notifications from 'stderr' to 'postmaster@example.com'
    #
    # m h dom mon dow user command
    #
    # Everyday 2:00AM, learn spam from a specific user
    # spam: junk directory
    0  2 * * * root  sa-learn --spam /var/mail/example.com/username/.Junk --dbpath /var/mail-state/lib-amavis/.spamassassin > /dev/null
    # ham: archive directories
    15 2 * * * root  sa-learn --ham /var/mail/example.com/username/.Archive* --dbpath /var/mail-state/lib-amavis/.spamassassin > /dev/null
    # ham: inbox subdirectories
    30 2 * * * root  sa-learn --ham /var/mail/example.com/username/cur* --dbpath /var/mail-state/lib-amavis/.spamassassin > /dev/null
    #
    # Everyday 3:00AM, learn spam from all users of a domain
    # spam: junk directory
    0  3 * * * root  sa-learn --spam /var/mail/not-example.com/*/.Junk --dbpath /var/mail-state/lib-amavis/.spamassassin > /dev/null
    # ham: archive directories
    15 3 * * * root  sa-learn --ham /var/mail/not-example.com/*/.Archive* --dbpath /var/mail-state/lib-amavis/.spamassassin > /dev/null
    # ham: inbox subdirectories
    30 3 * * * root  sa-learn --ham /var/mail/not-example.com/*/cur* --dbpath /var/mail-state/lib-amavis/.spamassassin > /dev/null
    ```

    Then with `compose.yaml`:

    ```yaml
    services:
      mailserver:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        volumes:
          - ./docker-data/dms/cron/sa-learn:/etc/cron.d/sa-learn
    ```

    Or with [Docker Swarm](https://docs.docker.com/engine/swarm/configs/):

    ```yaml
    services:
      mailserver:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        # ...
        configs:
          - source: my_sa_crontab
            target: /etc/cron.d/sa-learn

    configs:
      my_sa_crontab:
        file: ./docker-data/dms/cron/sa-learn
    ```

With the default settings, SpamAssassin will require 200 mails trained for spam (for example with the method explained above) and 200 mails trained for ham (using the same command as above but using `--ham` and providing it with some ham mails). Until you provided these 200+200 mails, SpamAssassin will not take the learned mails into account. For further reference, see the [SpamAssassin Wiki](https://wiki.apache.org/spamassassin/BayesNotWorking).

#### How do I have more control about what SpamAssassin is filtering?

By default, SPAM and INFECTED emails are put to a quarantine which is not very straight forward to access. Several config settings are affecting this behavior:

First, make sure you have the proper thresholds set:

```conf
SA_TAG=-100000.0
SA_TAG2=3.75
SA_KILL=100000.0
```

- The very negative value in `SA_TAG` makes sure, that all emails have the SpamAssassin headers included.
- `SA_TAG2` is the actual threshold to set the YES/NO flag for spam detection.
- `SA_KILL` needs to be very high, to make sure nothing is bounced at all (`SA_KILL` superseeds `SPAMASSASSIN_SPAM_TO_INBOX`)

Make sure everything (including SPAM) is delivered to the inbox and not quarantined:

```conf
SPAMASSASSIN_SPAM_TO_INBOX=1
```

Use `MOVE_SPAM_TO_JUNK=1` or create a sieve script which puts spam to the Junk folder:

```sieve
require ["comparator-i;ascii-numeric","relational","fileinto"];

if header :contains "X-Spam-Flag" "YES" {
  fileinto "Junk";
} elsif allof (
  not header :matches "x-spam-score" "-*",
  header :value "ge" :comparator "i;ascii-numeric" "x-spam-score" "3.75"
) {
  fileinto "Junk";
}
```

Create a dedicated mailbox for emails which are infected/bad header and everything amavis is blocking by default and put its address into `docker-data/dms/config/amavis.cf`

```cf
$clean_quarantine_to      = "amavis\@example.com";
$virus_quarantine_to      = "amavis\@example.com";
$banned_quarantine_to     = "amavis\@example.com";
$bad_header_quarantine_to = "amavis\@example.com";
$spam_quarantine_to       = "amavis\@example.com";
```

[fail2ban-customize]: ./config/security/fail2ban.md
[docs-maintenance]: ./config/advanced/maintenance/update-and-cleanup.md
[docs-override-postfix]: ./config/advanced/override-defaults/postfix.md
[docs-userpatches]: ./config/advanced/override-defaults/user-patches.md
[github-comment-baredomain]: https://github.com/docker-mailserver/docker-mailserver/issues/3048#issuecomment-1432358353
[github-comment-override-hostname]: https://github.com/docker-mailserver/docker-mailserver/issues/1731#issuecomment-753968425
[github-issue-95]: https://github.com/docker-mailserver/docker-mailserver/issues/95
[github-issue-97]: https://github.com/docker-mailserver/docker-mailserver/issues/97
[github-issue-1247]: https://github.com/docker-mailserver/docker-mailserver/issues/1247
[github-issue-1405-comment]: https://github.com/docker-mailserver/docker-mailserver/issues/1405#issuecomment-590106498
[github-issue-1639]: https://github.com/docker-mailserver/docker-mailserver/issues/1639
[github-issue-1792]: https://github.com/docker-mailserver/docker-mailserver/pull/1792
[hanscees-userpatches]: https://github.com/hanscees/dockerscripts/blob/master/scripts/tomav-user-patches.sh
[mail-state-folders]: https://github.com/docker-mailserver/docker-mailserver/blob/c7e498194546416fb7231cb03254e77e085d18df/target/scripts/startup/misc-stack.sh#L24-L33
[docs-optional-configuration]: ./config/advanced/optional-config.md
