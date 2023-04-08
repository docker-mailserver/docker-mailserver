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

!!! warning "DNS Caches & Propagation"

    While modern DNS providers are quick, it may take minutes or even hours for new DNS records to become available / propagate.

## DKIM

!!! quote "What is DKIM"

    DomainKeys Identified Mail (DKIM) is an email authentication method designed to detect forged sender addresses in email (email spoofing), a technique often used in phishing and email spam.

    [Source][wikipedia-dkim]

    [wikipedia-dkim]: https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail

DKIM is twofold:

1. Inbound mail is checked for DKIM signatures (whether they exist, and if so, whether they are correct)
2. (Your) Signatures should (if enabled and keys exist) be added to outbound mail

When OpenDKIM or Rspamd are enabled, checks for inbound mail are enabled automatically. You do not need to additionally setup anything. When you want to sign your own email, and we heavily encourage that you do, you need to read on.

!!! warning "RSA Key Sizes >= 4096 Bit"

    Keys of 4096 bits could de denied by some mail-servers. According to https://tools.ietf.org/html/rfc6376 keys are preferably between 512 and 2048 bits. See issue [#1854][github-issue-1854].

    [github-issue-1854]: https://github.com/docker-mailserver/docker-mailserver/issues/1854

### OpenDKIM

OpenDKIM is currently enabled by default, but can be disabled with `ENABLE_OPENDKIM=0`.

#### Generating Keys

The command `docker exec <CONTAINER NAME> setup dkim help` shows valuable information on our setup of OpenDKIM.

To enable DKIM signature, **you must have created at least one email account**. The script should ideally be run with a volume for _config_ attached (eg: `./docker-data/dms/config/:/tmp/docker-mailserver/`). Once you created an account, just run the following command to generate the signature:

```sh
docker exec -ti <CONTAINER NAME> config dkim
```

The default keysize when generating the signature is 4096 bits for now. If you need to change it (e.g. your DNS provider limits the size), then provide the size as the first parameter of the command:

```sh
./setup.sh config dkim keysize <keysize>
```

For LDAP systems that do not have any directly created user account you can run the following command (since `8.0.0`) to generate the signature by additionally providing the desired domain name (if you have multiple domains use the command multiple times or provide a comma-separated list of domains):

```sh
./setup.sh config dkim keysize <key-size> domain <example.com>[,<not-example.com>]
```

After generating DKIM (with OpenDKIM) keys, you should restart `docker-mailserver`.

#### Using Verify-Only Mode

If you want to run OpenDKIM in verify-only mode, you need to adjust `/etc/opendkim.conf` manually (e.g. with [`user-patches.sh`][docs-userpatches]):

```bash
sed -i -E 's|^(Mode[ ]*).*|\1v|g' /etc/opendkim.conf
echo 'ReportAddress           postmaster@example.com' >>/etc/opendkim.conf

```

[docs-userpatches]: ../advanced/override-defaults/user-patches.md

### Rspamd

TODO

### Follow-Up DNS Setup

Now the keys are generated, you need to configure your DNS zone, "simply" by adding a TXT record. We assume you are using a web-interface - if not, and you have access to a DNS zone _file_, you can copy the contents of the public key file into the file.

In the web-interface, create a new record of type `TXT`. If the selector you chose for the DKIM key was `mail`, the name of the record shpuld be `mail._domainkey` (i.e. the record is valid for the DNS name `mail._domainkey.example.com`). The value of the record should be

```txt
v=DKIM1; k=rsa; p=AZERTYUGHJKLMWX...
```

In the TTL field, you'll most likely want to pick your DNS proiders default. Then save the record - and you're done.

!!! danger "Confusing File Format"

    Whether you're using OpenDMARC or Rspamd, the public key file has a confusing (at first) structure. The structure is used because you could directly copy this file's contents into a DNS zone file. When using a web-interface though, you need to take care you copy and concatenate the lines correctly.

    When your file looks like this:

    ```txt
    dkim-rsa._domainkey IN TXT ( "v=DKIM1; k=rsa; "
    "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqQMMqhb1S52Rg7VFS3EC6JQIMxNDdiBmOKZvY5fiVtD3Z+yd9ZV+V8e4IARVoMXWcJWSR6xkloitzfrRtJRwOYvmrcgugOalkmM0V4Gy/2aXeamuiBuUc4esDQEI3egmtAsHcVY1XCoYfs+9VqoHEq3vdr3UQ8zP/l+FP5UfcaJFCK/ZllqcO2P1GjIDVSHLdPpRHbMP/tU1a9mNZ"
    "5QMZBJ/JuJK/s+2bp8gpxKn8rh1akSQjlynlV9NI+7J3CC7CUf3bGvoXIrb37C/lpJehS39KNtcGdaRufKauSfqx/7SxA0zyZC+r13f7ASbMaQFzm+/RRusTqozY/p/MsWx8QIDAQAB"
    ) ;
    ```

    the value of your DNS record for DKIM should look like this:

    ```txt
    v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqQMMqhb1S52Rg7VFS3EC6JQIMxNDdiBmOKZvY5fiVtD3Z+yd9ZV+V8e4IARVoMXWcJWSR6xkloitzfrRtJRwOYvmrcgugOalkmM0V4Gy/2aXeamuiBuUc4esDQEI3egmtAsHcVY1XCoYfs+9VqoHEq3vdr3UQ8zP/l+FP5UfcaJFCK/ZllqcO2P1GjIDVSHLdPpRHbMP/tU1a9mNZ5QMZBJ/JuJK/s+2bp8gpxKn8rh1akSQjlynlV9NI+7J3CC7CUf3bGvoXIrb37C/lpJehS39KNtcGdaRufKauSfqx/7SxA0zyZC+r13f7ASbMaQFzm+/RRusTqozY/p/MsWx8QIDAQAB
    ```

    And `dig` should confirm that:

    ```console
    $ dig +short TXT dkim-rsa._domainkey.example.com
    "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqQMMqhb1S52Rg7VFS3EC6JQIMxNDdiBmOKZvY5fiVtD3Z+yd9ZV+V8e4IARVoMXWcJWSR6xkloitzfrRtJRwOYvmrcgugOalkmM0V4Gy/2aXeamuiBuUc4esDQEI3egmtAsHcVY1XCoYfs+9VqoHEq3vdr3UQ8zP/l+FP5UfcaJFCK/ZllqcO2P1GjIDVSHLdPpRHbMP/tU1a9mNZ5QMZBJ/JuJK/s+2bp8gpxKn8rh1akSQjlynlV9NI+7J3CC7CUf3bGvoXIrb37C/lpJehS39" "KNtcGdaRufKauSfqx/7SxA0zyZC+r13f7ASbMaQFzm+/RRusTqozY/p/MsWx8QIDAQAB"
    ```

### Debugging Issues

[MxToolbox has a DKIM Verifier][mxtoolbox-dkim-verifier] that you can use to check your DKIM DNS record(s).

When using Rspamd, we recommend you turn on `check_pubkey = true;` in `dkim_signing.conf`. Rspamd will then check whether your private key matches your public key, and you can check possible mismatches by looking at `/var/log/supervisor/rspamd.log`.

[mxtoolbox-dkim-verifier]: https://mxtoolbox.com/dkim.aspx

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
