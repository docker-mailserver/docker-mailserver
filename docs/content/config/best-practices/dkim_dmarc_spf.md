# DKIM, DMARC & SPF

Cloudflare has written an [article about DKIM, DMARC and SPF][cloudflare-dkim-dmarc-spf] that we highly recommend you to read to get acquainted with the topic.

!!! note "Rspamd vs Individual validators"

    With v12.0.0, Rspamd was integrated into DMS. It can perform validations for DKIM, DMARC and SPF as part of the `spam-score-calculation` for an email. DMS provides individual alternatives for each validation that can be used instead of deferring to Rspamd:

    - DKIM: `opendkim` is used as a milter (like Rspamd)
    - DMARC: `opendmarc` is used as a milter (like Rspamd)
    - SPF: `policyd-spf` is used in Postfix's `smtpd_recipient_restrictions`

    In a future release Rspamd will become the default for these validations, with a deprecation notice issued prior to the removal of the above alternatives.

    We encourage everyone to prefer Rspamd via `ENABLE_RSPAMD=1`.

!!! warning "DNS Caches & Propagation"

    While modern DNS providers are quick, it may take minutes or even hours for new DNS records to become available / propagate.

## DKIM

!!! quote "What is DKIM"

    DomainKeys Identified Mail (DKIM) is an email authentication method designed to detect forged sender addresses in email (email spoofing), a technique often used in phishing and email spam.

    [Source][wikipedia-dkim]

When DKIM is enabled:

1. Inbound mail will verify any included DKIM signatures
2. Outbound mail is signed (_when you're sending domain has a configured DKIM key_)

DKIM requires a public/private key pair to enable **signing (_via private key_)** your outgoing mail, while the receiving end must query DNS to **verify (_via public key_)** that the signature is trustworthy.

### Generating Keys

You'll need to repeat this process if you add any new domains.

You should have:

- At least one [email account setup][docs-accounts-add]
- Attached a [volume for config][docs-volumes-config] to persist the generated files to local storage

!!! example "Creating DKIM Keys"

    DKIM keys can be generated with good defaults by running:

    ```bash
    docker exec -it <CONTAINER NAME> setup config dkim
    ```

    If you need to generate your keys with different settings, check the `help` output for supported config options and examples:

    ```bash
    docker exec -it <CONTAINER NAME> setup config dkim help
    ```

    As described by the help output, you may need to use the `domain` option explicitly when you're using LDAP or Rspamd.

??? info "Changing the key size"

    The keypair generated for using with DKIM presently defaults to RSA-2048. This is a good size but you can lower the security to `1024-bit`, or increase it to `4096-bit` (_discouraged as that is excessive_).
    
    To generate a key with different size (_for RSA 1024-bit_) run:

    ```sh
    setup config dkim keysize 1024
    ```

    !!! warning "RSA Key Sizes >= 4096 Bit"

        According to [RFC 8301][rfc-8301], keys are preferably between 1024 and 2048 bits. Keys of size 4096-bit or larger may not be compatible to all systems your mail is intended for.

        You [should not need a key length beyond 2048-bit][github-issue-dkimlength]. If 2048-bit does not meet your security needs, you may want to instead consider adopting key rotation or switching from RSA to ECC keys for DKIM.

??? note "You may need to specify mail domains explicitly"

    Required when using LDAP and Rspamd.

    `setup config dkim` will generate DKIM keys for what is assumed as the primary mail domain (_derived from the FQDN assigned to DMS, minus any subdomain_).

    When the DMS FQDN is `mail.example.com` or `example.com`, by default this command will generate DKIM keys for `example.com` as the primary domain for your users mail accounts (eg: `hello@example.com`).

    The DKIM generation does not have support to query LDAP for additionanl mail domains it should know about. If the primary mail domain is not sufficient, then you must explicitly specify any extra domains via the `domain` option:

    ```sh
    # ENABLE_OPENDKIM=1 (default):
    setup config dkim domain 'example.com,another-example.com'

    # ENABLE_RSPAMD=1 + ENABLE_OPENDKIM=0:
    setup config dkim domain example.com
    setup config dkim domain another-example.com
    ```

    !!! info "OpenDKIM with `ACCOUNT_PROVISIONER=FILE`"

        When DMS uses this configuration, it will by default also detect mail domains (_from accounts added via `setup email add`_), generating additional DKIM keys.

DKIM is currently supported by either OpenDKIM or Rspamd:

=== "OpenDKIM"

    OpenDKIM is currently [enabled by default][docs-env-opendkim].

    After running `setup config dkim`, your new DKIM key files (_and OpenDKIM config_) have been added to `/tmp/docker-mailserver/opendkim/`.

    !!! info "Restart required"

        After restarting DMS, outgoing mail will now be signed with your new DKIM key(s) :tada:

=== "Rspamd"

    Requires opt-in via [`ENABLE_RSPAMD=1`][docs-env-rspamd] (_and disable the default OpenDKIM: `ENABLE_OPENDKIM=0`_).

    Rspamd provides DKIM support through two separate modules:

    1. [Verifying DKIM signatures from inbound mail][rspamd-docs-dkim-checks] is enabled by default.
    2. [Signing outbound mail with your DKIM key][rspamd-docs-dkim-signing] needs additional setup (key + dns + config).

    ??? warning "Using Multiple Domains"

        If you have multiple domains, you need to:

        - Create a key wth `docker exec -it <CONTAINER NAME> setup config dkim domain <DOMAIN>` for each domain DMS should sign outgoing mail for.
        - Provide a custom `dkim_signing.conf` (for which an example is shown below), as the default config only supports one domain.

    !!! info "About the Helper Script"

        The script will persist the keys in `/tmp/docker-mailserver/rspamd/dkim/`. Hence, if you are already using the default volume mounts, the keys are persisted in a volume. The script also restarts Rspamd directly, so changes take effect without restarting DMS.

        The script provides you with log messages along the way of creating keys. In case you want to read the complete log, use `-v` (verbose) or `-vv` (very verbose).

        ---

        In case you have not already provided a default DKIM signing configuration, the script will create one and write it to `/etc/rspamd/override.d/dkim_signing.conf`. If this file already exists, it will not be overwritten.

        When you're already using [the `rspamd/override.d/` directory][docs-rspamd-config-dropin], the file is created inside your volume and therefore persisted correctly. If you are not using `rspamd/override.d/`, you will need to persist the file yourself (otherwise it is lost on container restart).

        An example of what a default configuration file for DKIM signing looks like can be found by expanding the example below.

    ??? example "DKIM Signing Module Configuration Examples"

        A simple configuration could look like this:

        ```cf
        # documentation: https://rspamd.com/doc/modules/dkim_signing.html

        enabled = true;

        sign_authenticated = true;
        sign_local = true;

        use_domain = "header";
        use_redis = false; # don't change unless Redis also provides the DKIM keys
        use_esld = true;
        check_pubkey = true; # you want to use this in the beginning

        domain {
            example.com {
                path = "/tmp/docker-mailserver/rspamd/dkim/mail.private";
                selector = "mail";
            }
        }
        ```

        As shown next:

        - You can add more domains into the `domain { ... }` section (in the following example: `example.com` and `example.org`).
        - A domain can also be configured with multiple selectors and keys within a `selectors [ ... ]` array (in the following example, this is done for `example.org`).

        ```cf
        # ...

        domain {
            example.com {
                path = /tmp/docker-mailserver/rspamd/example.com/ed25519.private";
                selector = "dkim-ed25519";
            }
            example.org {
                selectors [
                    {
                        path = "/tmp/docker-mailserver/rspamd/dkim/example.org/rsa.private";
                        selector = "dkim-rsa";
                    },
                    {
                        path = "/tmp/docker-mailserver/rspamd/dkim/example.org/ed25519.private";
                        selector = "dkim-ed25519";
                    }
                ]
            }
        }
        ```

    ??? warning "Support for DKIM Keys using ED25519"

        This modern elliptic curve is supported by Rspamd, but support by third-parties for [verifying Ed25519 DKIM signatures is unreliable][dkim-ed25519-support].

        If you sign your mail with this key type, you should include RSA as a fallback, like shown in the above example.

    ??? tip "Let Rspamd Check Your Keys"

        When `check_pubkey = true;` is set, Rspamd will query the DNS record for each DKIM selector, verifying each public key matches the private key configured.

        If there is a mismatch, a warning will be emitted to the Rspamd log `/var/log/mail/rspamd.log`.

### DNS Record { #dkim-dns }

When mail signed with your DKIM key is sent from your mail server, the receiver needs to check a DNS `TXT` record to verify the DKIM signature is trustworthy.

!!! example "Configuring DNS - DKIM record"

    When you generated your key in the previous step, the DNS data was saved into a file `<selector>.txt` (default: `mail.txt`). Use this content to update your [DNS via Web Interface][dns::example-webui] or directly edit your [DNS Zone file][dns::wikipedia-zonefile]:

    === "Web Interface"

        Create a new record:

        | Field | Value                                                                          |
        | ----- | ------------------------------------------------------------------------------ |
        | Type  | `TXT`                                                                          |
        | Name  | `<selector>._domainkey` (_default: `mail._domainkey`_)                         |
        | TTL   | Use the default (_otherwise [3600 seconds is appropriate][dns::digicert-ttl]_) |
        | Data  | File content within `( ... )` (_formatted as advised below_)                   |

        When using Rspamd, the helper script has already provided you with the contents (the "Data" field) of the DNS record you need to create - you can just copy-paste this text.

    === "DNS Zone file"

        `<selector>.txt` is already formatted as a snippet for adding to your [DNS Zone file][dns::wikipedia-zonefile].

        Just copy/paste the file contents into your existing DNS zone. The `TXT` value has been split into separate strings every 255 characters for compatibility.

??? info "`<selector>.txt` - Formatting the `TXT` record value correctly"

    This file was generated for use within a [DNS zone file][dns::wikipedia-zonefile]. The file name uses the DKIM selector it was generated with (default DKIM selector is `mail`, which creates `mail.txt`_).

    For your DNS setup, DKIM support needs to create a `TXT` record to store the public key for mail clients to use. `TXT` records with values that are longer than 255 characters need to be split into multiple parts. This is why the generated `<selector>.txt` file (_containing your public key for use with DKIM_) has multiple value parts wrapped within double-quotes between `(` and `)`.

    A DNS web-interface may handle this separation internally instead, and [could expect the value provided all as a single line][dns::webui-dkim] instead of split. When that is required, you'll need to manually format the value as described below.

    Your generated DNS record file (`<selector>.txt`) should look similar to this:

    ```txt
    mail._domainkey IN TXT ( "v=DKIM1; k=rsa; "
    "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqQMMqhb1S52Rg7VFS3EC6JQIMxNDdiBmOKZvY5fiVtD3Z+yd9ZV+V8e4IARVoMXWcJWSR6xkloitzfrRtJRwOYvmrcgugOalkmM0V4Gy/2aXeamuiBuUc4esDQEI3egmtAsHcVY1XCoYfs+9VqoHEq3vdr3UQ8zP/l+FP5UfcaJFCK/ZllqcO2P1GjIDVSHLdPpRHbMP/tU1a9mNZ"
    "5QMZBJ/JuJK/s+2bp8gpxKn8rh1akSQjlynlV9NI+7J3CC7CUf3bGvoXIrb37C/lpJehS39KNtcGdaRufKauSfqx/7SxA0zyZC+r13f7ASbMaQFzm+/RRusTqozY/p/MsWx8QIDAQAB"
    ) ;
    ```

    Take the content between `( ... )`, and combine all the quote wrapped content and remove the double-quotes including the white-space between them. That is your `TXT` record value, the above example would become this:

    ```txt
    v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqQMMqhb1S52Rg7VFS3EC6JQIMxNDdiBmOKZvY5fiVtD3Z+yd9ZV+V8e4IARVoMXWcJWSR6xkloitzfrRtJRwOYvmrcgugOalkmM0V4Gy/2aXeamuiBuUc4esDQEI3egmtAsHcVY1XCoYfs+9VqoHEq3vdr3UQ8zP/l+FP5UfcaJFCK/ZllqcO2P1GjIDVSHLdPpRHbMP/tU1a9mNZ5QMZBJ/JuJK/s+2bp8gpxKn8rh1akSQjlynlV9NI+7J3CC7CUf3bGvoXIrb37C/lpJehS39KNtcGdaRufKauSfqx/7SxA0zyZC+r13f7ASbMaQFzm+/RRusTqozY/p/MsWx8QIDAQAB
    ```

    To test that your new DKIM record is correct, query it with the `dig` command. The `TXT` value response should be a single line split into multiple parts wrapped in double-quotes:

    ```console
    $ dig +short TXT mail._domainkey.example.com
    "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqQMMqhb1S52Rg7VFS3EC6JQIMxNDdiBmOKZvY5fiVtD3Z+yd9ZV+V8e4IARVoMXWcJWSR6xkloitzfrRtJRwOYvmrcgugOalkmM0V4Gy/2aXeamuiBuUc4esDQEI3egmtAsHcVY1XCoYfs+9VqoHEq3vdr3UQ8zP/l+FP5UfcaJFCK/ZllqcO2P1GjIDVSHLdPpRHbMP/tU1a9mNZ5QMZBJ/JuJK/s+2bp8gpxKn8rh1akSQjlynlV9NI+7J3CC7CUf3bGvoXIrb37C/lpJehS39" "KNtcGdaRufKauSfqx/7SxA0zyZC+r13f7ASbMaQFzm+/RRusTqozY/p/MsWx8QIDAQAB"
    ```

### Troubleshooting { #dkim-debug }

[MxToolbox has a DKIM Verifier][mxtoolbox-dkim-verifier] that you can use to check your DKIM DNS record(s).

When using Rspamd, we recommend you turn on `check_pubkey = true;` in `dkim_signing.conf`. Rspamd will then check whether your private key matches your public key, and you can check possible mismatches by looking at `/var/log/mail/rspamd.log`.

## DMARC

With DMS, DMARC is pre-configured out of the box. You may disable extra and excessive DMARC checks when using Rspamd via `ENABLE_OPENDMARC=0`.

The only thing you need to do in order to enable DMARC on a "DNS-level" is to add new `TXT`. In contrast to [DKIM](#dkim), DMARC DNS entries do not require any keys, but merely setting the [configuration values][dmarc-howto-configtags]. You can either handcraft the entry by yourself or use one of available generators (like [this one][dmarc-tool-gca]).

Typically something like this should be good to start with:

```txt
_dmarc.example.com. IN TXT "v=DMARC1; p=none; sp=none; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400; rua=mailto:dmarc.report@example.com; ruf=mailto:dmarc.report@example.com"
```

Or a bit more strict policies (_mind `p=quarantine` and `sp=quarantine`_):

```txt
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; sp=quarantine; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400; rua=mailto:dmarc.report@example.com; ruf=mailto:dmarc.report@example.com"
```

The DMARC status may not be displayed instantly due to delays in DNS (caches). Dmarcian has [a few tools][dmarcian-tools] you can use to verify your DNS records.

## SPF

!!! quote "What is SPF"

    Sender Policy Framework (SPF) is a simple email-validation system designed to detect email spoofing by providing a mechanism to allow receiving mail exchangers to check that incoming mail from a domain comes from a host authorized by that domain's administrators.

    [Source][wikipedia-spf]

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

Then add this line to `compose.yaml`:

```yaml
volumes:
  - ./docker-data/dms/config/postfix-policyd-spf.conf:/etc/postfix-policyd-spf-python/policyd-spf.conf
```

[docs-accounts-add]: ../user-management.md#adding-a-new-account
[docs-volumes-config]: ../advanced/optional-config.md
[docs-env-opendkim]: ../environment.md#enable_opendkim
[docs-env-rspamd]: ../environment.md#enable_rspamd
[docs-rspamd-config-dropin]: ../security/rspamd.md#manually
[cloudflare-dkim-dmarc-spf]: https://www.cloudflare.com/learning/email-security/dmarc-dkim-spf/
[rfc-8301]: https://datatracker.ietf.org/doc/html/rfc8301#section-3.2
[github-issue-dkimlength]: https://github.com/docker-mailserver/docker-mailserver/issues/1854#issuecomment-806280929
[rspamd-docs-dkim-checks]: https://www.rspamd.com/doc/modules/dkim.html
[rspamd-docs-dkim-signing]: https://www.rspamd.com/doc/modules/dkim_signing.html
[dns::example-webui]: https://www.vultr.com/docs/introduction-to-vultr-dns/
[dns::digicert-ttl]: https://www.digicert.com/faq/dns/what-is-ttl
[dns::wikipedia-zonefile]: https://en.wikipedia.org/wiki/Zone_file
[dns::webui-dkim]: https://serverfault.com/questions/763815/route-53-doesnt-allow-adding-dkim-keys-because-length-is-too-long
[dkim-ed25519-support]: https://serverfault.com/questions/1023674/is-ed25519-well-supported-for-the-dkim-validation/1074545#1074545
[mxtoolbox-dkim-verifier]: https://mxtoolbox.com/dkim.aspx
[dmarc-howto-configtags]: https://github.com/internetstandards/toolbox-wiki/blob/master/DMARC-how-to.md#overview-of-dmarc-configuration-tags
[dmarc-tool-gca]: https://dmarcguide.globalcyberalliance.org
[dmarcian-tools]: https://dmarcian.com/dmarc-tools/
[wikipedia-dkim]: https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail
[wikipedia-spf]: https://en.wikipedia.org/wiki/Sender_Policy_Framework
