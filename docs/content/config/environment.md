---
title: Environment Variables
---

!!! info

    Values in **bold** are the default values. If an option doesn't work as documented here, check if you are running the latest image. The current `master` branch corresponds to the image `ghcr.io/docker-mailserver/docker-mailserver:edge`.

#### General

##### OVERRIDE_HOSTNAME

If you can't set your hostname (_eg: you're in a container platform that doesn't let you_) specify it via this environment variable. It will have priority over `docker run --hostname`, or the equivalent `hostname:` field in `compose.yaml`.

- **empty** => Uses the `hostname -f` command to get canonical hostname for DMS to use.
- => Specify an FQDN (fully-qualified domain name) to serve mail for. The hostname is required for DMS to function correctly.

##### LOG_LEVEL

Set the log level for DMS. This is mostly relevant for container startup scripts and change detection event feedback.

Valid values (in order of increasing verbosity) are: `error`, `warn`, `info`, `debug` and `trace`. The default log level is `info`.

##### SUPERVISOR_LOGLEVEL

Here you can adjust the [log-level for Supervisor](http://supervisord.org/logging.html#activity-log-levels). Possible values are

- critical => Only show critical messages
- error    => Only show erroneous output
- **warn** => Show warnings
- info     => Normal informational output
- debug    => Also show debug messages

The log-level will show everything in its class and above.

##### DMS_VMAIL_UID

Default: 5000

The User ID assigned to the static vmail user for `/var/mail` (_Mail storage managed by Dovecot_).

##### DMS_VMAIL_GID

Default: 5000

The Group ID assigned to the static vmail group for `/var/mail` (_Mail storage managed by Dovecot_).

##### ONE_DIR

- 0 => state in default directories.
- **1** => consolidate all states into a single directory (`/var/mail-state`) to allow persistence using docker volumes. See the [related FAQ entry][docs-faq-onedir] for more information.

##### ACCOUNT_PROVISIONER

Configures the provisioning source of user accounts (including aliases) for user queries and authentication by services managed by DMS (_Postfix and Dovecot_).

User provisioning via OIDC is planned for the future, see [this tracking issue](https://github.com/docker-mailserver/docker-mailserver/issues/2713).

- **empty** => use FILE
- LDAP => use LDAP authentication
- OIDC => use OIDC authentication (**not yet implemented**)
- FILE => use local files (this is used as the default)

A second container for the ldap service is necessary (e.g. [`bitnami/openldap`](https://hub.docker.com/r/bitnami/openldap/)).

##### PERMIT_DOCKER

Set different options for mynetworks option (can be overwrite in postfix-main.cf) **WARNING**: Adding the docker network's gateway to the list of trusted hosts, e.g. using the `network` or `connected-networks` option, can create an [**open relay**](https://en.wikipedia.org/wiki/Open_mail_relay), for instance if IPv6 is enabled on the host machine but not in Docker.

- **none** => Explicitly force authentication
- container => Container IP address only.
- host => Add docker host (ipv4 only).
- network => Add the docker default bridge network (172.16.0.0/12); **WARNING**: `docker-compose` might use others (e.g. 192.168.0.0/16) use `PERMIT_DOCKER=connected-networks` in this case.
- connected-networks => Add all connected docker networks (ipv4 only).

Note: you probably want to [set `POSTFIX_INET_PROTOCOLS=ipv4`](#postfix_inet_protocols) to make it work fine with Docker.

##### TZ

Set the timezone. If this variable is unset, the container runtime will try to detect the time using `/etc/localtime`, which you can alternatively mount into the container. The value of this variable must follow the pattern `AREA/ZONE`, i.e. of you want to use Germany's time zone, use `Europe/Berlin`. You can lookup all available timezones [here](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List).

##### ENABLE_AMAVIS

Amavis content filter (used for ClamAV & SpamAssassin)

- 0     => Amavis is disabled
- **1** => Amavis is enabled

##### AMAVIS_LOGLEVEL

[This page](https://lists.amavis.org/pipermail/amavis-users/2011-March/000158.html) provides information on Amavis' logging statistics.

- -1/-2/-3 => Only show errors
- **0**    => Show warnings
- 1/2      => Show default informational output
- 3/4/5    => log debug information (very verbose)

##### ENABLE_DNSBL

This enables DNS block lists in _Postscreen_. If you want to know which lists we are using, have a look at [the default `main.cf` for Postfix we provide](https://github.com/docker-mailserver/docker-mailserver/blob/master/target/postfix/main.cf) and search for `postscreen_dnsbl_sites`.

!!! danger "A Warning On DNS Block Lists"

    Make sure your DNS queries are properly resolved, i.e. you will most likely not want to use a public DNS resolver as these queries do not return meaningful results. We try our best to only evaluate proper return codes - this is not a guarantee that all codes are handled fine though.

    **Note that emails will be rejected if they don't pass the block list checks!**

- **0** => DNS block lists are disabled
- 1     => DNS block lists are enabled

##### ENABLE_OPENDKIM

Enables the OpenDKIM service.

- **1** => Enabled
- 0 => Disabled

##### ENABLE_OPENDMARC

Enables the OpenDMARC service.

- **1** => Enabled
- 0 => Disabled

##### ENABLE_POLICYD_SPF

Enabled `policyd-spf` in Postfix's configuration. You will likely want to set this to `0` in case you're using Rspamd ([`ENABLE_RSPAMD=1`](#enable_rspamd)).

- 0 => Disabled
- **1** => Enabled

##### ENABLE_POP3

- **empty** => POP3 service disabled
- 1 => Enables POP3 service

##### ENABLE_CLAMAV

- **0** => ClamAV is disabled
- 1 => ClamAV is enabled

##### ENABLE_FAIL2BAN

- **0** => fail2ban service disabled
- 1 => Enables fail2ban service

If you enable Fail2Ban, don't forget to add the following lines to your `compose.yaml`:

``` BASH
cap_add:
  - NET_ADMIN
```

Otherwise, `nftables` won't be able to ban IPs.

##### FAIL2BAN_BLOCKTYPE

- **drop**   => drop packet (send NO reply)
- reject => reject packet (send ICMP unreachable)
FAIL2BAN_BLOCKTYPE=drop

##### SMTP_ONLY

- **empty** => all daemons start
- 1 => only launch postfix smtp

##### SSL_TYPE

In the majority of cases, you want `letsencrypt` or `manual`.

`self-signed` can be used for testing SSL until you provide a valid certificate, note that third-parties cannot trust `self-signed` certificates, do not use this type in production. `custom` is a temporary workaround that is not officially supported.

- **empty** => SSL disabled.
- letsencrypt => Support for using certificates with _Let's Encrypt_ provisioners. (Docs: [_Let's Encrypt_ Setup][docs-tls-letsencrypt])
- manual => Provide your own certificate via separate key and cert files. (Docs: [Bring Your Own Certificates][docs-tls-manual])
    - Requires: `SSL_CERT_PATH` and `SSL_KEY_PATH` ENV vars to be set to the location of the files within the container.
    - Optional: `SSL_ALT_CERT_PATH` and `SSL_ALT_KEY_PATH` allow providing a 2nd certificate as a fallback for dual (aka hybrid) certificate support. Useful for ECDSA with an RSA fallback. _Presently only `manual` mode supports this feature_.
- custom => Provide your own certificate as a single file containing both the private key and full certificate chain. (Docs: `None`)
- self-signed => Provide your own self-signed certificate files. Expects a self-signed CA cert for verification. **Use only for local testing of your setup**. (Docs: [Self-Signed Certificates][docs-tls-selfsigned])

Please read [the SSL page in the documentation][docs-tls] for more information.

##### TLS_LEVEL

- **empty** => modern
- modern => Enables TLSv1.2 and modern ciphers only. (default)
- intermediate => Enables TLSv1, TLSv1.1 and TLSv1.2 and broad compatibility ciphers.

##### SPOOF_PROTECTION

Configures the handling of creating mails with forged sender addresses.

- **0** => (not recommended) Mail address spoofing allowed. Any logged in user may create email messages with a [forged sender address](https://en.wikipedia.org/wiki/Email_spoofing).
- 1 => Mail spoofing denied. Each user may only send with his own or his alias addresses. Addresses with [extension delimiters](http://www.postfix.org/postconf.5.html#recipient_delimiter) are not able to send messages.

##### ENABLE_SRS

Enables the Sender Rewriting Scheme. SRS is needed if DMS acts as forwarder. See [postsrsd](https://github.com/roehling/postsrsd/blob/master/README.md#sender-rewriting-scheme-crash-course) for further explanation.

- **0** => Disabled
- 1 => Enabled

##### NETWORK_INTERFACE

In case your network interface differs from `eth0`, e.g. when you are using HostNetworking in Kubernetes, you can set this to whatever interface you want. This interface will then be used.

- **empty** => `eth0`

##### VIRUSMAILS_DELETE_DELAY

Set how many days a virusmail will stay on the server before being deleted

- **empty** => 7 days

##### POSTFIX_DAGENT

Configure Postfix `virtual_transport` to deliver mail to a different LMTP client (_default is a unix socket to dovecot_).

Provide any valid URI. Examples:

- **empty** => `lmtp:unix:/var/run/dovecot/lmtp` (default, configured in Postfix `main.cf`)
- `lmtp:unix:private/dovecot-lmtp` (use socket)
- `lmtps:inet:<host>:<port>` (secure lmtp with starttls)
- `lmtp:<kopano-host>:2003` (use kopano as mailstore)

##### POSTFIX\_MAILBOX\_SIZE\_LIMIT

Set the mailbox size limit for all users. If set to zero, the size will be unlimited (default).

- **empty** => 0 (no limit)

##### ENABLE_QUOTAS

- **1** => Dovecot quota is enabled
- 0 => Dovecot quota is disabled

See [mailbox quota][docs-accounts-quota].

##### POSTFIX\_MESSAGE\_SIZE\_LIMIT

Set the message size limit for all users. If set to zero, the size will be unlimited (not recommended!)

- **empty** => 10240000 (~10 MB)

##### CLAMAV_MESSAGE_SIZE_LIMIT

Mails larger than this limit won't be scanned.
ClamAV must be enabled (ENABLE_CLAMAV=1) for this.

- **empty** => 25M (25 MB)

##### ENABLE_MANAGESIEVE

- **empty** => Managesieve service disabled
- 1 => Enables Managesieve on port 4190

##### POSTMASTER_ADDRESS

- **empty** => postmaster@example.com
- => Specify the postmaster address

##### ENABLE_UPDATE_CHECK

Check for updates on container start and then once a day. If an update is available, a mail is send to POSTMASTER_ADDRESS.

- 0 => Update check disabled
- **1** => Update check enabled

##### UPDATE_CHECK_INTERVAL

Customize the update check interval. Number + Suffix. Suffix must be 's' for seconds, 'm' for minutes, 'h' for hours or 'd' for days.

- **1d** => Check for updates once a day

##### POSTSCREEN_ACTION

- **enforce** => Allow other tests to complete. Reject attempts to deliver mail with a 550 SMTP reply, and log the helo/sender/recipient information. Repeat this test the next time the client connects.
- drop => Drop the connection immediately with a 521 SMTP reply. Repeat this test the next time the client connects.
- ignore => Ignore the failure of this test. Allow other tests to complete. Repeat this test the next time the client connects. This option is useful for testing and collecting statistics without blocking mail.

##### DOVECOT_MAILBOX_FORMAT

- **maildir** => uses very common Maildir format, one file contains one message
- sdbox => (experimental) uses Dovecot high-performance mailbox format, one file contains one message
- mdbox ==> (experimental) uses Dovecot high-performance mailbox format, multiple messages per file and multiple files per box

This option has been added in November 2019. Using other format than Maildir is considered as experimental in docker-mailserver and should only be used for testing purpose. For more details, please refer to [Dovecot Documentation](https://wiki2.dovecot.org/MailboxFormat).

##### POSTFIX_REJECT_UNKNOWN_CLIENT_HOSTNAME

If enabled, employs `reject_unknown_client_hostname` to sender restrictions in Postfix's configuration.

- **0** => Disabled
- 1 => Enabled

##### POSTFIX_INET_PROTOCOLS

- **all** => Listen on all interfaces.
- ipv4 => Listen only on IPv4 interfaces. Most likely you want this behind Docker.
- ipv6 => Listen only on IPv6 interfaces.

Note: More details at <http://www.postfix.org/postconf.5.html#inet_protocols>

##### DOVECOT_INET_PROTOCOLS

- **all** => Listen on all interfaces
- ipv4 => Listen only on IPv4 interfaces. Most likely you want this behind Docker.
- ipv6 => Listen only on IPv6 interfaces.

Note: More information at <https://dovecot.org/doc/dovecot-example.conf>

##### MOVE_SPAM_TO_JUNK

When enabled, e-mails marked with the

1. `X-Spam: Yes` header added by Rspamd
2. `X-Spam-Flag: YES` header added by SpamAssassin (requires [`SPAMASSASSIN_SPAM_TO_INBOX=1`](#spamassassin_spam_to_inbox))

will be automatically moved to the Junk folder (with the help of a Sieve script).

- 0 => Spam messages will be delivered in the mailbox.
- **1** => Spam messages will be delivered in the `Junk` folder.

##### MARK_SPAM_AS_READ

Enable to treat received spam as "read" (_avoids notification to MUA client of new mail_).

Mail is received as spam when it has been marked with either header:

1. `X-Spam: Yes` (_by Rspamd_)
2. `X-Spam-Flag: YES` (_by SpamAssassin - requires [`SPAMASSASSIN_SPAM_TO_INBOX=1`](#spamassassin_spam_to_inbox)_)

- **0** => disabled
- 1 => Spam messages will be marked as read

#### Rspamd

##### ENABLE_RSPAMD

Enable or disable [Rspamd][docs-rspamd].

- **0** => disabled
- 1 => enabled

##### ENABLE_RSPAMD_REDIS

Explicit control over running a Redis instance within the container. By default, this value will match what is set for [`ENABLE_RSPAMD`](#enable_rspamd).

The purpose of this setting is to opt-out of starting an internal Redis instance when enabling Rspamd, replacing it with your own external instance.

??? note "Configuring Rspamd for an external Redis instance"

    You will need to [provide configuration][rspamd-redis-config] at `/etc/rspamd/local.d/redis.conf` similar to:

    ```
    servers = "redis.example.test:6379";
    expand_keys = true;
    ```

[rspamd-redis-config]: https://rspamd.com/doc/configuration/redis.html

- 0 => Disabled
- 1 => Enabled

##### RSPAMD_CHECK_AUTHENTICATED

This settings controls whether checks should be performed on emails coming from authenticated users (i.e. most likely outgoing emails). The default value is `0` in order to align better with SpamAssassin. **We recommend** reading through [the Rspamd documentation on scanning outbound emails][rspamd-scanning-outbound] though to decide for yourself whether you need and want this feature.

- **0** => No checks will be performed for authenticated users
- 1 => All default checks will be performed for authenticated users

[rspamd-scanning-outbound]: https://rspamd.com/doc/tutorials/scanning_outbound.html

##### RSPAMD_GREYLISTING

Controls whether the [Rspamd Greylisting module][rspamd-greylisting-module] is enabled. This module can further assist in avoiding spam emails by [greylisting] e-mails with a certain spam score.

- **0** => Disabled
- 1 => Enabled

[rspamd-greylisting-module]: https://rspamd.com/doc/modules/greylisting.html
[greylisting]: https://en.wikipedia.org/wiki/Greylisting_(email)

##### RSPAMD_LEARN

When enabled,

1. the "[autolearning][rspamd-autolearn]" feature is turned on;
2. the Bayes classifier will be trained (with the help of Sieve scripts) when moving mails
    1. from anywhere to the `Junk` folder (learning this email as spam);
    2. from the `Junk` folder into the `INBOX` (learning this email as ham).

!!! warning "Attention"

    As of now, the spam learning database is global (i.e. available to all users). If one user deliberately trains it with malicious data, then it will ruin your detection rate.

    This feature is suitably only for users who can tell ham from spam and users that can be trusted.

[rspamd-autolearn]: https://rspamd.com/doc/configuration/statistic.html#autolearning

- **0** => Disabled
- 1 => Enabled

##### RSPAMD_HFILTER

Can be used to enable or disable the [Hfilter group module][rspamd-docs-hfilter-group-module]. This is used by DMS to adjust the `HFILTER_HOSTNAME_UNKNOWN` symbol, increasing its default weight to act similar to Postfix's `reject_unknown_client_hostname`, without the need to outright reject a message.

- 0 => Disabled
- **1** => Enabled

[rspamd-docs-hfilter-group-module]: https://www.rspamd.com/doc/modules/hfilter.html

##### RSPAMD_HFILTER_HOSTNAME_UNKNOWN_SCORE

Can be used to control the score when the [`HFILTER_HOSTNAME_UNKNOWN` symbol](#rspamd_hfilter) applies. A higher score is more punishing. Setting it to 15 (the default score for rejecting an e-mail) is equivalent to rejecting the email when the check fails.

Default: 6 (which corresponds to the `add_header` action)

#### Reports

##### PFLOGSUMM_TRIGGER

Enables regular Postfix log summary ("pflogsumm") mail reports.

- **not set** => No report
- daily_cron => Daily report for the previous day
- logrotate => Full report based on the mail log when it is rotated

This is a new option. The old REPORT options are still supported for backwards compatibility.
If this is not set and reports are enabled with the old options, logrotate will be used.

##### PFLOGSUMM_RECIPIENT

Recipient address for Postfix log summary reports.

- **not set** => Use POSTMASTER_ADDRESS
- => Specify the recipient address(es)

##### PFLOGSUMM_SENDER

Sender address (`FROM`) for pflogsumm reports (if Postfix log summary reports are enabled).

- **not set** => Use REPORT_SENDER
- => Specify the sender address

##### LOGWATCH_INTERVAL

Interval for logwatch report.

- **none** => No report is generated
- daily => Send a daily report
- weekly => Send a report every week

##### LOGWATCH_RECIPIENT

Recipient address for logwatch reports if they are enabled.

- **not set** => Use REPORT_RECIPIENT or POSTMASTER_ADDRESS
- => Specify the recipient address(es)

##### LOGWATCH_SENDER

Sender address (`FROM`) for logwatch reports if logwatch reports are enabled.

- **not set** => Use REPORT_SENDER
- => Specify the sender address

##### REPORT_RECIPIENT

Defines who receives reports (if they are enabled).

- **empty** => Use POSTMASTER_ADDRESS
- => Specify the recipient address

##### REPORT_SENDER

Defines who sends reports (if they are enabled).

- **empty** => `mailserver-report@<YOUR DOMAIN>`
- => Specify the sender address

##### LOGROTATE_INTERVAL

Changes the interval in which log files are rotated.

- **weekly** => Rotate log files weekly
- daily => Rotate log files daily
- monthly => Rotate log files monthly

!!! note

    `LOGROTATE_INTERVAL` only manages `logrotate` within the container for services we manage internally.

    The entire log output for the container is still available via `docker logs mailserver` (or your respective container name). If you want to configure external log rotation for that container output as well, : [Docker Logging Drivers](https://docs.docker.com/config/containers/logging/configure/).

    By default, the logs are lost when the container is destroyed (eg: re-creating via `docker compose down && docker compose up -d`). To keep the logs, mount a volume (to `/var/log/mail/`).

!!! note

    This variable can also determine the interval for Postfix's log summary reports, see [`PFLOGSUMM_TRIGGER`](#pflogsumm_trigger).

#### SpamAssassin

##### ENABLE_SPAMASSASSIN

- **0** => SpamAssassin is disabled
- 1 => SpamAssassin is enabled

##### SPAMASSASSIN_SPAM_TO_INBOX

- 0 => Spam messages will be bounced (_rejected_) without any notification (_dangerous_).
- **1** => Spam messages will be delivered to the inbox and tagged as spam using `SA_SPAM_SUBJECT`.

##### ENABLE_SPAMASSASSIN_KAM

[KAM](https://mcgrail.com/template/projects#KAM1) is a 3rd party SpamAssassin ruleset, provided by the McGrail Foundation. If SpamAssassin is enabled, KAM can be used in addition to the default ruleset.

- **0** => KAM disabled
- 1 => KAM enabled

##### SA_TAG

- **2.0** => add spam info headers if at, or above that level

Note: this SpamAssassin setting needs `ENABLE_SPAMASSASSIN=1`

##### SA_TAG2

- **6.31** => add 'spam detected' headers at that level

Note: this SpamAssassin setting needs `ENABLE_SPAMASSASSIN=1`

##### SA_KILL

- **10.0** => triggers spam evasive actions

!!! note "This SpamAssassin setting needs `ENABLE_SPAMASSASSIN=1`"

    By default, DMS is configured to quarantine spam emails.

    If emails are quarantined, they are compressed and stored in a location dependent on the `ONE_DIR` setting above. To inhibit this behaviour and deliver spam emails, set this to a very high value e.g. `100.0`.

    If `ONE_DIR=1` (default) the location is `/var/mail-state/lib-amavis/virusmails/`, or if `ONE_DIR=0`: `/var/lib/amavis/virusmails/`. These paths are inside the docker container.

##### SA_SPAM_SUBJECT

- **\*\*\*SPAM\*\*\*** => add tag to subject if spam detected

Note: this SpamAssassin setting needs `ENABLE_SPAMASSASSIN=1`. Add the SpamAssassin score to the subject line by inserting the keyword \_SCORE\_: **\*\*\*SPAM(\_SCORE\_)\*\*\***.

##### SA_SHORTCIRCUIT_BAYES_SPAM

- **1** => will activate SpamAssassin short circuiting for bayes spam detection.

This will uncomment the respective line in ```/etc/spamassasin/local.cf```

Note: activate this only if you are confident in your bayes database for identifying spam.

##### SA_SHORTCIRCUIT_BAYES_HAM

- **1** => will activate SpamAssassin short circuiting for bayes ham detection

This will uncomment the respective line in ```/etc/spamassasin/local.cf```

Note: activate this only if you are confident in your bayes database for identifying ham.

#### Fetchmail

##### ENABLE_FETCHMAIL

- **0** => `fetchmail` disabled
- 1 => `fetchmail` enabled

##### FETCHMAIL_POLL

- **300** => `fetchmail` The number of seconds for the interval

##### FETCHMAIL_PARALLEL

  **0** => `fetchmail` runs with a single config file `/etc/fetchmailrc`
  **1** => `/etc/fetchmailrc` is split per poll entry. For every poll entry a separate fetchmail instance is started  to allow having multiple imap idle configurations defined.

Note: The defaults of your fetchmailrc file need to be at the top of the file. Otherwise it won't be added correctly to all separate `fetchmail` instances.
#### Getmail

##### ENABLE_GETMAIL

Enable or disable `getmail`.

- **0** => Disabled
- 1 => Enabled

##### GETMAIL_POLL

- **5** => `getmail` The number of minutes for the interval. Min: 1; Max: 30; Default: 5.

#### LDAP



##### LDAP_START_TLS

- **empty** => no
- yes => LDAP over TLS enabled for Postfix

##### LDAP_SERVER_HOST

- **empty** => mail.example.com
- => Specify the `<dns-name>` / `<ip-address>` where the LDAP server is reachable via a URI like: `ldaps://mail.example.com`.
- Note: You must include the desired URI scheme (`ldap://`, `ldaps://`, `ldapi://`).

##### LDAP_SEARCH_BASE

- **empty** => ou=people,dc=domain,dc=com
- => e.g. LDAP_SEARCH_BASE=dc=mydomain,dc=local

##### LDAP_BIND_DN

- **empty** => cn=admin,dc=domain,dc=com
- => take a look at examples of SASL_LDAP_BIND_DN

##### LDAP_BIND_PW

- **empty** => admin
- => Specify the password to bind against ldap

##### LDAP_QUERY_FILTER_USER

- e.g. `(&(mail=%s)(mailEnabled=TRUE))`
- => Specify how ldap should be asked for users

##### LDAP_QUERY_FILTER_GROUP

- e.g. `(&(mailGroupMember=%s)(mailEnabled=TRUE))`
- => Specify how ldap should be asked for groups

##### LDAP_QUERY_FILTER_ALIAS

- e.g. `(&(mailAlias=%s)(mailEnabled=TRUE))`
- => Specify how ldap should be asked for aliases

##### LDAP_QUERY_FILTER_DOMAIN

- e.g. `(&(|(mail=*@%s)(mailalias=*@%s)(mailGroupMember=*@%s))(mailEnabled=TRUE))`
- => Specify how ldap should be asked for domains

##### LDAP_QUERY_FILTER_SENDERS

- **empty**  => use user/alias/group maps directly, equivalent to `(|($LDAP_QUERY_FILTER_USER)($LDAP_QUERY_FILTER_ALIAS)($LDAP_QUERY_FILTER_GROUP))`
- => Override how ldap should be asked if a sender address is allowed for a user

##### DOVECOT_TLS

- **empty** => no
- yes => LDAP over TLS enabled for Dovecot

#### Dovecot

The following variables overwrite the default values for ```/etc/dovecot/dovecot-ldap.conf.ext```.

##### DOVECOT_BASE

- **empty** =>  same as `LDAP_SEARCH_BASE`
- => Tell Dovecot to search only below this base entry. (e.g. `ou=people,dc=domain,dc=com`)

##### DOVECOT_DEFAULT_PASS_SCHEME

- **empty** =>  `SSHA`
- => Select one crypt scheme for password hashing from this list of [password schemes](https://doc.dovecot.org/configuration_manual/authentication/password_schemes/).

##### DOVECOT_DN

- **empty** => same as `LDAP_BIND_DN`
- => Bind dn for LDAP connection. (e.g. `cn=admin,dc=domain,dc=com`)

##### DOVECOT_DNPASS

- **empty** => same as `LDAP_BIND_PW`
- => Password for LDAP dn specified in `DOVECOT_DN`.

##### DOVECOT_URIS

- **empty** => same as `LDAP_SERVER_HOST`
- => Specify a space separated list of LDAP URIs.
- Note: You must include the desired URI scheme (`ldap://`, `ldaps://`, `ldapi://`).

##### DOVECOT_LDAP_VERSION

- **empty** => 3
- 2 => LDAP version 2 is used
- 3 => LDAP version 3 is used

##### DOVECOT_AUTH_BIND

- **empty** => no
- yes => Enable [LDAP authentication binds](https://wiki.dovecot.org/AuthDatabase/LDAP/AuthBinds)

##### DOVECOT_USER_FILTER

- e.g. `(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))`

##### DOVECOT_USER_ATTRS

- e.g. `homeDirectory=home,qmailUID=uid,qmailGID=gid,mailMessageStore=mail`
- => Specify the directory to dovecot attribute mapping that fits your directory structure.
- Note: This is necessary for directories that do not use the Postfix Book Schema.
- Note: The left-hand value is the directory attribute, the right hand value is the dovecot variable.
- More details on the [Dovecot Wiki](https://wiki.dovecot.org/AuthDatabase/LDAP/Userdb)

##### DOVECOT_PASS_FILTER

- e.g. `(&(objectClass=PostfixBookMailAccount)(uniqueIdentifier=%n))`
- **empty** => same as `DOVECOT_USER_FILTER`

##### DOVECOT_PASS_ATTRS

- e.g. `uid=user,userPassword=password`
- => Specify the directory to dovecot variable mapping that fits your directory structure.
- Note: This is necessary for directories that do not use the Postfix Book Schema.
- Note: The left-hand value is the directory attribute, the right hand value is the dovecot variable.
- More details on the [Dovecot Wiki](https://wiki.dovecot.org/AuthDatabase/LDAP/PasswordLookups)

#### Postgrey

##### ENABLE_POSTGREY

- **0** => `postgrey` is disabled
- 1 => `postgrey` is enabled

##### POSTGREY_DELAY

- **300** => greylist for N seconds

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

##### POSTGREY_MAX_AGE

- **35** => delete entries older than N days since the last time that they have been seen

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

##### POSTGREY_AUTO_WHITELIST_CLIENTS

- **5** => whitelist host after N successful deliveries (N=0 to disable whitelisting)

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

##### POSTGREY_TEXT

- **Delayed by Postgrey** => response when a mail is greylisted

Note: This postgrey setting needs `ENABLE_POSTGREY=1`

#### SASL Auth

##### ENABLE_SASLAUTHD

- **0** => `saslauthd` is disabled
- 1 => `saslauthd` is enabled

##### SASLAUTHD_MECHANISMS

- **empty** => pam
- `ldap` => authenticate against ldap server
- `shadow` => authenticate against local user db
- `mysql` => authenticate against mysql db
- `rimap` => authenticate against imap server
- NOTE: can be a list of mechanisms like pam ldap shadow

##### SASLAUTHD_MECH_OPTIONS

- **empty** => None
- e.g. with SASLAUTHD_MECHANISMS rimap you need to specify the ip-address/servername of the imap server  ==> xxx.xxx.xxx.xxx

##### SASLAUTHD_LDAP_SERVER

- **empty** => same as `LDAP_SERVER_HOST`
- Note: You must include the desired URI scheme (`ldap://`, `ldaps://`, `ldapi://`).

##### SASLAUTHD_LDAP_START_TLS

- **empty** => `no`
- `yes` => Enable `ldap_start_tls` option

##### SASLAUTHD_LDAP_TLS_CHECK_PEER

- **empty** => `no`
- `yes` => Enable `ldap_tls_check_peer` option

##### SASLAUTHD_LDAP_TLS_CACERT_DIR

Path to directory with CA (Certificate Authority) certificates.

- **empty** => Nothing is added to the configuration
- Any value => Fills the `ldap_tls_cacert_dir` option

##### SASLAUTHD_LDAP_TLS_CACERT_FILE

File containing CA (Certificate Authority) certificate(s).

- **empty** => Nothing is added to the configuration
- Any value => Fills the `ldap_tls_cacert_file` option

##### SASLAUTHD_LDAP_BIND_DN

- **empty** => same as `LDAP_BIND_DN`
- specify an object with privileges to search the directory tree
- e.g. active directory: SASLAUTHD_LDAP_BIND_DN=cn=Administrator,cn=Users,dc=mydomain,dc=net
- e.g. openldap: SASLAUTHD_LDAP_BIND_DN=cn=admin,dc=mydomain,dc=net

##### SASLAUTHD_LDAP_PASSWORD

- **empty** => same as `LDAP_BIND_PW`

##### SASLAUTHD_LDAP_SEARCH_BASE

- **empty** => same as `LDAP_SEARCH_BASE`
- specify the search base

##### SASLAUTHD_LDAP_FILTER

- **empty** => default filter `(&(uniqueIdentifier=%u)(mailEnabled=TRUE))`
- e.g. for active directory: `(&(sAMAccountName=%U)(objectClass=person))`
- e.g. for openldap: `(&(uid=%U)(objectClass=person))`

##### SASLAUTHD_LDAP_PASSWORD_ATTR

Specify what password attribute to use for password verification.

- **empty** => Nothing is added to the configuration but the documentation says it is `userPassword` by default.
- Any value => Fills the `ldap_password_attr` option

##### SASLAUTHD_LDAP_AUTH_METHOD

- **empty** => `bind` will be used as a default value
- `fastbind` => The fastbind method is used
- `custom` => The custom method uses userPassword attribute to verify the password

##### SASLAUTHD_LDAP_MECH

Specify the authentication mechanism for SASL bind.

- **empty** => Nothing is added to the configuration
- Any value => Fills the `ldap_mech` option

#### SRS (Sender Rewriting Scheme)

##### SRS_SENDER_CLASSES

An email has an "envelope" sender (indicating the sending server) and a
"header" sender (indicating who sent it). More strict SPF policies may require
you to replace both instead of just the envelope sender.

[More info](https://www.mybluelinux.com/what-is-email-envelope-and-email-header/).

- **envelope_sender** => Rewrite only envelope sender address
- header_sender => Rewrite only header sender (not recommended)
- envelope_sender,header_sender => Rewrite both senders

##### SRS_EXCLUDE_DOMAINS

- **empty** => Envelope sender will be rewritten for all domains
- provide comma separated list of domains to exclude from rewriting

##### SRS_SECRET

- **empty** => generated when the container is started for the first time
- provide a secret to use in base64
- you may specify multiple keys, comma separated. the first one is used for signing and the remaining will be used for verification. this is how you rotate and expire keys
- if you have a cluster/swarm make sure the same keys are on all nodes
- example command to generate a key: `dd if=/dev/urandom bs=24 count=1 2>/dev/null | base64`

##### SRS_DOMAINNAME

- **empty** => Derived from [`OVERRIDE_HOSTNAME`](#override_hostname), `$DOMAINNAME` (internal), or the container's hostname
- Set this if auto-detection fails, isn't what you want, or you wish to have a separate container handle DSNs

#### Default Relay Host

##### DEFAULT_RELAY_HOST

- **empty** => don't set default relayhost setting in main.cf
- default host and port to relay all mail through.
    Format: `[example.com]:587` (don't forget the brackets if you need this to
    be compatible with `$RELAY_USER` and `$RELAY_PASSWORD`, explained below).

#### Multi-domain Relay Hosts

##### RELAY_HOST

- **empty** => don't configure relay host
- default host to relay mail through

##### RELAY_PORT

- **empty** => 25
- default port to relay mail through

##### RELAY_USER

- **empty** => no default
- default relay username (if no specific entry exists in postfix-sasl-password.cf)

##### RELAY_PASSWORD

- **empty** => no default
- password for default relay user

[docs-rspamd]: ./security/rspamd.md
[docs-faq-onedir]: ../faq.md#what-about-docker-datadmsmail-state-folder-varmail-state-internally
[docs-tls]: ./security/ssl.md
[docs-tls-letsencrypt]: ./security/ssl.md#lets-encrypt-recommended
[docs-tls-manual]: ./security/ssl.md#bring-your-own-certificates
[docs-tls-selfsigned]: ./security/ssl.md#self-signed-certificates
[docs-accounts-quota]: ./user-management.md#quotas
