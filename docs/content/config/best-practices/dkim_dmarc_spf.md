# DKIM, DMARC & SPF

Cloudflare has written an [article about DKIM, DMARC and SPF][cloudflare-dkim-dmarc-spf] that we highly recommend you to read to get acquainted with the topic.

[cloudflare-dkim-dmarc-spf]: https://www.cloudflare.com/learning/email-security/dmarc-dkim-spf/

!!! note "Rspamd vs The Rest"

    With v12.0.0, Rspamd was integrated into DMS. It will perform validations for DKIM, DMARC and SPF "all-in-one" as part of the spam-score-calculation for an email. But DMS also packs software that does the validations for each of these mechanisms on its own:

    - for DKIM: `opendkim` is used as a milter (like Rspamd)
    - for DMARC: `opendmarc` is used as a milter (like Rspamd)
    - for SPF: `policyd-spf` is used in Postfix's `smtpd_recipient_restrictions`

    We plan on removing the individual services in favor of Rspamd. This will not happen soon though. We will

    1. Change the defaults first (disabling the services by default)
    2. Then deprecate them
    3. Finally remove them

    The removal is not expected to happen before v15.0.0 of DMS. We encourage everyone to switch to Rspamd before that though.

## DKIM

### With OpenDKIM

TODO

### With Rspamd

TODO

## DMARC

With DMS, DMARC is pre-configured out of the box. You may disable extra and excessive DMARC checks when using Rspamd via `ENABLE_OPENDMARC=0`.

The only thing you need to do in order to enable DMARC on a "DNS-level" is to add new `TXT`. In contrast to [DKIM](#dkim), DMARC DNS entries do not require any keys, but merely setting the [configuration values][dmarc-howto-configtags]. You can either handcraft the entry by yourself or use one of available generators (like [this one][dmarc-tool-gca]).

Typically something like this should be good to start with:

```txt
_dmarc.example.com. IN TXT "v=DMARC1; p=none; sp=none; fo=0; adkim=4; aspf=r; pct=100; rf=afrf; ri=86400; rua=mailto:dmarc.report@example.com; ruf=mailto:dmarc.report@example.com"
```

Or a bit more strict policies (_mind `p=quarantine` and `sp=quarantine`_):

```txt
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; sp=quarantine; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400; rua=mailto:dmarc.report@example.com; ruf=mailto:dmarc.report@example.com"
```

The DMARC status may not be displayed instantly due to delays in DNS (caches). Dmarcian has [a few tools][dmarcian-tools] you can use to verify your DNS records.

[dmarc-howto-configtags]: https://github.com/internetstandards/toolbox-wiki/blob/master/DMARC-how-to.md#overview-of-dmarc-configuration-tags
[dmarc-tool-gca]: https://dmarcguide.globalcyberalliance.org
[dmarcian-tools]: https://dmarcian.com/dmarc-tools/

## SPF

!!! quote "What is SPF"

    Sender Policy Framework (SPF) is a simple email-validation system designed to detect email spoofing by providing a mechanism to allow receiving mail exchangers to check that incoming mail from a domain comes from a host authorized by that domain's administrators.

    [Source][wikipedia-spf]

    [wikipedia-spf]: https://en.wikipedia.org/wiki/Sender_Policy_Framework

!!! note "Disabling `policyd-spf`?"

    As of now, `policyd-spf` cannot be disabled. This is WIP.

### Adding an SPF Record

To add a SPF record in your DNS, insert the following line in your DNS zone:

```txt
example.com. IN TXT "v=spf1 mx ~all"
```

This enables the _Softfail_ mode for SPF. You could first add this SPF record with a very low TTL. _SoftFail_ is a good setting for getting started and testing, as it lets all email through, with spams tagged as such in the mailbox.

After verification, you _might_ want to change your SPF record to `v=spf1 mx -all` so as to enforce the _HardFail_ policy. See <http://www.open-spf.org/SPF_Record_Syntax> for more details about SPF policies.

In any case, increment the SPF record's TTL to its final value.

### Backup MX & Secondary MX for `policyd-spf`

For whitelisting an IP Address from the SPF test, you can create a config file (see [`policyd-spf.conf`](https://www.linuxcertif.com/man/5/policyd-spf.conf)) and mount that file into `/etc/postfix-policyd-spf-python/policyd-spf.conf`.

**Example:** Create and edit a `policyd-spf.conf` file at `docker-data/dms/config/postfix-policyd-spf.conf`:

```conf
debugLevel = 1
#0(only errors)-4(complete data received)

skip_addresses = 127.0.0.0/8,::ffff:127.0.0.0/104,::1

# Preferably use IP-Addresses for whitelist lookups:
Whitelist = 192.168.0.0/31,192.168.1.0/30
# Domain_Whitelist = mx1.not-example.com,mx2.not-example.com
```

Then add this line to `docker-compose.yml`:

```yaml
volumes:
  - ./docker-data/dms/config/postfix-policyd-spf.conf:/etc/postfix-policyd-spf-python/policyd-spf.conf
```
