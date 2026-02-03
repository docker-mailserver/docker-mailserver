---
title: Environment Variables
---

!!! info

    Values in **bold** are the default values. If an option doesn't work as documented here, check if you are running the latest image. The current `master` branch corresponds to the image `ghcr.io/docker-mailserver/docker-mailserver:edge`.

!!! tip

    If an environment variable `<VAR>__FILE` is set with a valid file path as the value, the content of that file will become the value for `<VAR>` (_provided `<VAR>` has not already been set_).

#### General

##### OVERRIDE_HOSTNAME

If you cannot set your DMS FQDN as your hostname (_eg: you're in a container runtime lacks the equivalent of Docker's `--hostname`_), specify it via this environment variable.

- **empty** => Internally uses the `hostname --fqdn` command to get the canonical hostname assigned to the DMS container.
- => Specify an FQDN (fully-qualified domain name) to serve mail for. The hostname is required for DMS to function correctly.

!!! info

    `OVERRIDE_HOSTNAME` is checked early during DMS container setup. When set it will be preferred over querying the containers hostname via the `hostname --fqdn` command (_configured via `docker run --hostname` or the equivalent `hostname:` field in `compose.yaml`_).

!!! warning "Compatibility may differ"

    `OVERRIDE_HOSTNAME` is not a complete replacement for adjusting the containers configured hostname. It is a best effort workaround for supporting deployment environments like Kubernetes or when using Docker with `--network=host`.

    Typically this feature is only useful when software supports configuring a specific hostname to use, instead of a default fallback that infers the hostname (such as retrieving the hostname via libc / NSS). [Fetchmail is known to be incompatible][gh--issue::hostname-compatibility] with this ENV, requiring manual workarounds.

    Compatibility differences are being [tracked here][gh-issue::dms-fqdn] as they become known.

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

!!! warning "Incompatible UID values"

    - A value of [`0` (root) is not compatible][gh-issue::vmail-uid-cannot-be-root].
    - This feature will attempt to adjust the `uid` for the `docker` user (`/etc/passwd`), hence the error emitted to logs if the UID is already assigned to another user.
    - The feature appears to work with other UID values that are already assigned in `/etc/passwd`, even though Dovecot by default has a setting for the minimum UID as `500`.

##### DMS_VMAIL_GID

Default: 5000

The Group ID assigned to the static vmail group for `/var/mail` (_Mail storage managed by Dovecot_).

##### ACCOUNT_PROVISIONER

Configures the [provisioning source of user accounts][docs::account-management::overview] (including aliases) for user queries and authentication by services managed by DMS (_Postfix and Dovecot_).

- **FILE** => use local files
- LDAP => use LDAP authentication

LDAP requires an external service (e.g. [`bitnami/openldap`](https://hub.docker.com/r/bitnami/openldap/)).

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

##### ENABLE_MTA_STS

Enables MTA-STS support for outbound mail.

- **0** => Disabled
- 1 => Enabled

See [MTA-STS](best-practices/mta-sts.md) for further explanation.

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

- **0** => POP3 service disabled
- 1 => Enables POP3 service

##### ENABLE_IMAP

- 0 => Disabled
- **1** => Enabled

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
- `modern` => Limits the cipher suite to secure ciphers only.
- `intermediate` => Relaxes security by adding additional ciphers for broader compatibility.

!!! info

    In both cases TLS v1.2 is the minimum protocol version supported.

!!! note

    Prior to DMS v12.0, `TLS_LEVEL=intermediate` additionally supported TLS versions 1.0 and 1.1. If you still have legacy devices that can only use these versions of TLS, please follow [this workaround advice][gh-issue::tls-legacy-workaround].

##### SPOOF_PROTECTION

Configures the handling of creating mails with forged sender addresses.

- **0** => (not recommended) Mail address spoofing allowed. Any logged in user may create email messages with a [forged sender address](https://en.wikipedia.org/wiki/Email_spoofing).
- 1 => Mail spoofing denied. Each user may only send with their own or their alias addresses. Addresses with [extension delimiters](http://www.postfix.org/postconf.5.html#recipient_delimiter) are not able to send messages.

To allow certain accounts to send as other addresses, set the `SPOOF_PROTECTION` to `1` and see [the Aliases page in the documentation][docs-aliases].

##### ENABLE_SRS

Enables the Sender Rewriting Scheme. SRS is needed if DMS acts as forwarder. See [postsrsd](https://github.com/roehling/postsrsd/blob/main/README.rst) for further explanation.

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

##### POSTFIX_MAILBOX_SIZE_LIMIT

Set the mailbox size limit for all users. If set to zero, the size will be unlimited (default). Size is in bytes.

- **empty** => 0 (no limit)

##### ENABLE_QUOTAS

- **1** => Dovecot quota is enabled
- 0 => Dovecot quota is disabled

See [mailbox quota][docs-accounts-quota].

!!! info "Compatibility"

    This feature is presently only compatible with `ACCOUNT_PROVISIONER=FILE`.

    When using a different provisioner (or `SMTP_ONLY=1`) this ENV will instead default to `0`.

##### POSTFIX_MESSAGE_SIZE_LIMIT

Set the message size limit for all users. If set to zero, the size will be unlimited (not recommended!). Size is in bytes.

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

This option has been added in November 2019. Using other format than Maildir is considered as experimental in docker-mailserver and should only be used for testing purpose. For more details, please refer to [Dovecot Documentation](https://doc.dovecot.org/admin_manual/mailbox_formats/#mailbox-formats).

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

- 0 => Spam messages will be delivered to the inbox.
- **1** => Spam messages will be delivered to the Junk mailbox.

Routes mail identified as spam into the recipient(s) Junk mailbox (_a specialized folder for junk associated to the [special-use flag `\Junk`][docs::dovecot::special-use-flag], handled via a Dovecot sieve script internally_).

[docs::dovecot::special-use-flag]: ../examples/use-cases/imap-folders.md

!!! info

    Mail is received as spam when it has been marked with either header:

    - `X-Spam: Yes` (_added by Rspamd_)
    - `X-Spam-Flag: YES` (_added by SpamAssassin - requires [`SPAMASSASSIN_SPAM_TO_INBOX=1`](#spamassassin_spam_to_inbox)_)

##### MARK_SPAM_AS_READ

- **0** => disabled
- 1 => Spam messages will be marked as read

Enable to treat received spam as "read" (_avoids notification to MUA client of new mail_).

!!! info

    Mail is received as spam when it has been marked with either header:

    - `X-Spam: Yes` (_added by Rspamd_)
    - `X-Spam-Flag: YES` (_added by SpamAssassin - requires [`SPAMASSASSIN_SPAM_TO_INBOX=1`](#spamassassin_spam_to_inbox)_)

##### SPAM_SUBJECT

This variable defines a prefix for e-mails tagged with the `X-Spam: Yes` (Rspamd) or `X-Spam-Flag: YES` (SpamAssassin/Amavis) header.

Default: empty (no prefix will be added to e-mails)

??? example "Including trailing white-space"

    Add trailing white-space by quote wrapping the value: `SPAM_SUBJECT='[SPAM] '`

##### DMS_CONFIG_POLL

Defines how often DMS polls [monitored config files][gh::monitored-configs] for changes in the DMS Config Volume. This also includes TLS certificates and is often relied on for applying changes managed via `setup` CLI commands.

- **`2`** => How often (in seconds) [change detection][gh::check-for-changes] is performed.

!!! note "Decreasing the frequency of polling for changes"

    Raising the value will delay how soon a change is detected which may impact UX expectations for responsiveness, but reduces resource usage when changes are rare.

!!! info

    When using `ACCOUNT_PROVISIONER=LDAP`, the change detection feature is presently disabled.

[gh::check-for-changes]: https://github.com/docker-mailserver/docker-mailserver/blob/v15.0.0/target/scripts/check-for-changes.sh#L37
[gh::monitored-configs]: https://github.com/docker-mailserver/docker-mailserver/blob/v15.0.0/target/scripts/helpers/change-detection.sh#L30-L42

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

!!! note "Not all checks and actions are disabled"

    DKIM signing of e-mails will still happen.

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


##### RSPAMD_NEURAL

Can be used to enable or disable the [Neural network module][rspamd-docs-neural-network]. This is an experimental anti-spam weigh method using three neural networks in the configuration added here. As far as we can tell it trains itself by using other modules to find out what spam is. It will take a while (a week or more) to train its first neural network. The config trains new networks all the time and discards old networks.
Since it is experimental, it is switched off by default.

- **0** => Disabled
- 1 => Enabled

[rspamd-docs-neural-network]: https://www.rspamd.com/doc/modules/neural.html

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

##### LOGROTATE_COUNT

Defines how many files are kept by logrotate.

- **4** => Number of files

#### SpamAssassin

##### ENABLE_SPAMASSASSIN

- **0** => SpamAssassin is disabled
- 1 => SpamAssassin is enabled

??? info "SpamAssassin analyzes incoming mail and assigns a spam score"

    Integration with Amavis involves processing mail based on the assigned spam score via [`SA_TAG`, `SA_TAG2` and `SA_KILL`][amavis-docs::spam-score].

    These settings have equivalent ENV supported by DMS for easy adjustments, as documented below.

[amavis-docs::spam-score]: https://www.ijs.si/software/amavisd/amavisd-new-docs.html#tagkill

##### ENABLE_SPAMASSASSIN_KAM

- **0** => KAM disabled
- 1 => KAM enabled

[KAM](https://mcgrail.com/template/projects#KAM1) is a 3rd party SpamAssassin ruleset, provided by the McGrail Foundation. If SpamAssassin is enabled, KAM can be used in addition to the default ruleset.

##### SPAMASSASSIN_SPAM_TO_INBOX

- 0 => (_Amavis action: `D_BOUNCE`_): Spam messages will be bounced (_rejected_) without any notification (_dangerous_).
- **1** => (_Amavis action: `D_PASS`_): Spam messages will be delivered to the inbox.

!!! note

    The Amavis action configured by this setting:

    - Influences the behavior of the [`SA_KILL`](#sa_kill) setting.
    - Applies to the Amavis config parameters `$final_spam_destiny` and `$final_bad_header_destiny`.

!!! note "This ENV setting is related to"

    - [`MOVE_SPAM_TO_JUNK=1`](#move_spam_to_junk)
    - [`MARK_SPAM_AS_READ=1`](#mark_spam_as_read)
    - [`SPAM_SUBJECT`](#spam_subject)

##### SA_TAG

- **2.0** => add 'spam info' headers at, or above this spam score

Mail is not yet considered spam at this spam score, but for purposes like diagnostics it can be useful to identify mail with a spam score at a lower bound than `SA_TAG2`.

??? example "`X-Spam` headers appended to mail"

    Send a simple mail to a local DMS account `hello@example.com`:

    ```bash
    docker exec dms swaks --server 0.0.0.0 --to hello@example.com --body 'spam'
    ```

    Inspecting the raw mail you will notice several `X-Spam` headers were added to the mail like this:

    ```
    X-Spam-Flag: NO
    X-Spam-Score: 4.162
    X-Spam-Level: ****
    X-Spam-Status: No, score=4.162 tagged_above=2 required=4
            tests=[BODY_SINGLE_WORD=1, DKIM_ADSP_NXDOMAIN=0.8,
            NO_DNS_FOR_FROM=0.379, NO_RECEIVED=-0.001, NO_RELAYS=-0.001]
            autolearn=no autolearn_force=no
    ```

    !!! info "The `X-Spam-Score` is `4.162`"

        High enough for `SA_TAG` to trigger adding these headers, but not high enough for `SA_TAG2` (_which would set `X-Spam-Flag: YES` instead_).

##### SA_TAG2

- **6.31** => add 'spam detected' headers at, or above this level

When a spam score is high enough, mark mail as spam (_Appends the mail header: `X-Spam-Flag: YES`_).

!!! info "Interaction with other ENV"

    - [`SPAM_SUBJECT`](#spam_subject) modifies the mail subject to better communicate spam mail to the user.
    - [`MOVE_SPAM_TO_JUNK=1`](#move_spam_to_junk): The mail is still delivered, but to the recipient(s) junk folder instead. This feature reduces the usefulness of `SPAM_SUBJECT`.

##### SA_KILL

- **10.0** => quarantine + triggers action to handle spam

Controls the spam score threshold for triggering an action on mail that has a high spam score.

??? tip "Choosing an appropriate `SA_KILL` value"

    The value should be high enough to be represent confidence in mail as spam:

    - Too low: The action taken may prevent legitimate mail (ham) that was incorrectly detected as spam from being delivered successfully.
    - Too high: Allows more spam to bypass the `SA_KILL` trigger (_how to treat mail with high confidence that it is actually spam_).

    Experiences from DMS users with these settings has been [collected here][gh-issue::sa-tunables-insights], along with [some direct configuration guides][gh-issue::sa-tunables-guides] (_under "Resources for references"_).

[gh-issue::sa-tunables-insights]: https://github.com/docker-mailserver/docker-mailserver/pull/3058#issuecomment-1420268148
[gh-issue::sa-tunables-guides]: https://github.com/docker-mailserver/docker-mailserver/pull/3058#issuecomment-1416547911

??? info "Trigger action"

    DMS will configure Amavis with either of these actions based on the DMS [`SPAMASSASSIN_SPAM_TO_INBOX`](#spamassassin_spam_to_inbox) ENV setting:

    - `D_PASS` (**default**):
        - Accept mail and deliver it to the recipient(s), despite the high spam score. A copy is still stored in quarantine.
        - This is a good default to start with until you are more confident in an `SA_KILL` threshold that won't accidentally discard / bounce legitimate mail users are expecting to arrive but is detected as spam.
    - `D_BOUNCE`:
        - Additionally sends a bounce notification (DSN).
        - The [DSN is suppressed][amavis-docs::actions] (_no bounce sent_) when the spam score exceeds the Amavis `$sa_dsn_cutoff_level` config setting (default: `10`). With the DMS `SA_KILL` default also being `10`, no DSN will ever be sent.
    - `D_REJECT` / `D_DISCARD`:
        - These two aren't configured by DMS, but are valid alternative action values if configuring Amavis directly.

??? note "Quarantined mail"

    When mail has a spam score that reaches the `SA_KILL` threshold:

    - [It will be quarantined][amavis-docs::quarantine] regardless of the `SA_KILL` action to perform.
    - With `D_PASS` the delivered mail also appends an `X-Quarantine-ID` mail header. The ID value of this header is part of the quarantined file name.

    If emails are quarantined, they are compressed and stored at a location:

    - Default: `/var/lib/amavis/virusmails/`
    - When the [`/var/mail-state/` volume][docs::dms-volumes-state] is present: `/var/mail-state/lib-amavis/virusmails/`

    !!! tip

        Easily list mail stored in quarantine with `find` and the quarantine path:

        ```bash
        find /var/lib/amavis/virusmails -type f
        ```

[amavis-docs::actions]: https://www.ijs.si/software/amavisd/amavisd-new-docs.html#actions
[amavis-docs::quarantine]: https://www.ijs.si/software/amavisd/amavisd-new-docs.html#quarantine

##### SA_SHORTCIRCUIT_BAYES_SPAM

- **1** => will activate SpamAssassin short circuiting for bayes spam detection.

This will uncomment the respective line in `/etc/spamassassin/local.cf`

!!! warning

    Activate this only if you are confident in your bayes database for identifying spam.

##### SA_SHORTCIRCUIT_BAYES_HAM

- **1** => will activate SpamAssassin short circuiting for bayes ham detection

This will uncomment the respective line in `/etc/spamassassin/local.cf`

!!! warning

    Activate this only if you are confident in your bayes database for identifying ham.

#### Fetchmail

##### ENABLE_FETCHMAIL

- **0** => `fetchmail` disabled
- 1 => `fetchmail` enabled

##### FETCHMAIL_POLL

- **300** => `fetchmail` The number of seconds for the interval

##### FETCHMAIL_PARALLEL

- **0** => `fetchmail` runs with a single config file `/etc/fetchmailrc`
- 1 => `/etc/fetchmailrc` is split per poll entry. For every poll entry a separate fetchmail instance is started to [allow having multiple imap idle connections per server][fetchmail-imap-workaround] (_when poll entries reference the same IMAP server_).

[fetchmail-imap-workaround]: https://otremba.net/wiki/Fetchmail_(Debian)#Immediate_Download_via_IMAP_IDLE

Note: The defaults of your fetchmailrc file need to be at the top of the file. Otherwise it won't be added correctly to all separate `fetchmail` instances.
#### Getmail

##### ENABLE_GETMAIL

Enable or disable `getmail`.

- **0** => Disabled
- 1 => Enabled

##### GETMAIL_POLL

- **5** => `getmail` The number of minutes for the interval. Min: 1; Default: 5.


#### OAUTH2

##### ENABLE_OAUTH2

- **empty** => OAUTH2 authentication is disabled
- 1 => OAUTH2 authentication is enabled

##### OAUTH2_INTROSPECTION_URL

- => Specify the user info endpoint URL of the oauth2 provider (_eg: `https://oauth2.example.com/userinfo/`_)

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

DMS only implements support for these mechanisms:

- **`ldap`** => Authenticate against an LDAP server
- `rimap` => Authenticate against an IMAP server

##### SASLAUTHD_MECH_OPTIONS

- **empty** => None

!!! info

    With `SASLAUTHD_MECHANISMS=rimap` you need to specify the ip-address / servername of the IMAP server, such as `SASLAUTHD_MECH_OPTIONS=127.0.0.1`.

##### SASLAUTHD_LDAP_SERVER

- **empty** => Use the same value as `LDAP_SERVER_HOST`

!!! note

    You must include the desired URI scheme (`ldap://`, `ldaps://`, `ldapi://`).

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

#### Relay Host

Supported ENV for the [Relay Host][docs::relay-host] feature.

!!! note "Prefer `DEFAULT_RELAY_HOST` instead of `RELAY_HOST`"

    This is advised unless you need support for sender domain opt-out (via `setup relay exclude-domain`).

    The implementation for `RELAY_HOST` is not compatible with LDAP.

!!! tip "Opt-in for relay host support"

    Enable relaying only for specific sender domains instead by using `setup relay add-domain`.

    **NOTE:** Presently there is a caveat when relay host credentials are configured (_which is incompatible with opt-in_).

##### DEFAULT_RELAY_HOST

Configures a default relay host.

!!! info

    - All mail sent outbound from DMS will be relayed through the configured host, unless sender-dependent relayhost maps have been configured (_which have precedence_).
    - The host value may optionally be wrapped in brackets (_skips DNS query for MX record_): `[mail.example.com]:587` vs `example.com:587`

!!! abstract "Technical Details"

    This ENV internally configures the Postfix `main.cf` setting: [`relayhost`][postfix-config::relayhost]

##### RELAY_HOST

Configures a default relay host.

!!! note

    Expects a value like `mail.example.com`. Internally this will be wrapped to `[mail.example.com]`, so it should resolve to the MTA directly.

    !!! warning "Do not use with `DEFAULT_RELAY_HOST`"

        `RELAY_HOST` has precedence as it is configured with `sender_dependent_relayhost_maps`.

!!! info

    - This is a legacy ENV. It is however required for the opt-out feature of `postfix-relaymap.cf` to work.
    - Internal configuration however differs from `DEFAULT_RELAY_HOST`.

!!! abstract "Technical Details"

    This feature is configured internally using the:

    - Postfix setting with config: [`sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map`][postfix-config::relayhost_maps]
    - DMS Config volume support via: `postfix-relaymap.cf` (_generates `/etc/postfix/relayhost_map`_)

    All known mail domains managed by DMS will be configured to relay outbound mail to `RELAY_HOST` by adding them implicitly to `/etc/postfix/relayhost_map`, except for domains using the opt-out feature of `postfix-relaymap.cf`.

##### RELAY_PORT

Default => 25

Support for configuring a different port than 25 for `RELAY_HOST` to use.

!!! note

    Requires `RELAY_HOST`.

#### Relay Host Credentials

!!! warning "Configuring relay host credentials enforces outbound authentication"

    Presently when `RELAY_USER` + `RELAY_PASSWORD` or `postfix-sasl-password.cf` are configured, all outbound mail traffic is configured to require a secure connection established and forbids the omission of credentials.

    Additional feature work is required to only enforce these requirements on mail sent through a configured relay host.

##### RELAY_USER

##### RELAY_PASSWORD

Provide the credentials to use with `RELAY_HOST` or `DEFAULT_RELAY_HOST`.

!!! tip "Alternative credentials config"

    You may prefer to use `setup relay add-auth` to avoid risking ENV exposing secrets.

    - With the CLI command, you must provide relay credentials for each of your sender domains.
    - Alternatively manually edit `postfix-sasl-password.cf` with the correct relayhost entry (_`DEFAULT_RELAY_HOST` value, or as defined in `/etc/postfix/relayhost_map`_) to provide credentials per relayhost configured.

!!! abstract "Technical Details"

    Credentials for relay hosts are configured internally using the:

    - Postfix setting with config: [`smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd`][postfix-config::sasl_passwd]
    - DMS Config volume support via: `postfix-sasl-password.cf` (_generates `/etc/postfix/sasl_passwd`_)

    ---

    When `postfix-sasl-password.cf` is present, DMS will copy it internally to `/etc/postfix/sasl_passwd`.

    - DMS provides support for mapping credentials by sender domain:
        - Explicitly via `setup relay add-auth` (_creates / updates `postfix-sasl-password.cf`_).
        - Implicitly via the relay ENV support (_configures all known DMS managed domains to use the relay ENV_).
    - Credentials can be explicitly configured for specific relay hosts instead of sender domains:
        - Add the exact relayhost value (`host:port` / `[host]:port`) from the generated `/etc/postfix/relayhost_map`, or `main.cf:relayhost` (`DEFAULT_RELAY_HOST`).
        - `setup relay ...` is missing support, you must instead add these manually to `postfix-sasl-password.cf`.

[gh-issue::vmail-uid-cannot-be-root]: https://github.com/docker-mailserver/docker-mailserver/issues/4098#issuecomment-2257201025

[docs-rspamd]: ./security/rspamd.md
[docs-tls]: ./security/ssl.md
[docs-tls-letsencrypt]: ./security/ssl.md#lets-encrypt-recommended
[docs-tls-manual]: ./security/ssl.md#bring-your-own-certificates
[docs-tls-selfsigned]: ./security/ssl.md#self-signed-certificates
[docs-accounts-quota]: ./account-management/overview.md#quotas
[docs::account-management::overview]: ./account-management/overview.md
[docs::relay-host]: ./advanced/mail-forwarding/relay-hosts.md
[docs::dms-volumes-state]: ./advanced/optional-config.md#volumes-state
[postfix-config::relayhost]: https://www.postfix.org/postconf.5.html#relayhost
[postfix-config::relayhost_maps]: https://www.postfix.org/postconf.5.html#sender_dependent_relayhost_maps
[postfix-config::sasl_passwd]: https://www.postfix.org/postconf.5.html#smtp_sasl_password_maps
[gh-issue::tls-legacy-workaround]: https://github.com/docker-mailserver/docker-mailserver/pull/2945#issuecomment-1949907964
[gh-issue::hostname-compatibility]: https://github.com/docker-mailserver/docker-mailserver-helm/issues/168#issuecomment-2911782106
[gh-issue::dms-fqdn]: https://github.com/docker-mailserver/docker-mailserver/issues/3520#issuecomment-1700191973
