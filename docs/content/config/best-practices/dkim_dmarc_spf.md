# DKIM, DMARC & SPF

Cloudflare has written an [article about DKIM, DMARC and SPF][cloudflare-dkim-dmarc-spf] that we highly recommend you to read to get acquainted with the topic.

[cloudflare-dkim-dmarc-spf]: https://www.cloudflare.com/learning/email-security/dmarc-dkim-spf/

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

    [wikipedia-dkim]: https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail

DKIM is twofold:

1. Inbound mail will verify any DKIM signatures found.
2. Outbound mail is signed when you've provided a DKIM key for the sending domain.

DKIM support is handled by either:

- OpenDKIM (_[enabled by default][docs-env-opendkim]_)
- Rspamd (_opt-in via [`ENABLE_RSPAMD=1`][docs-env-rspamd]_)

When DKIM is enabled, checks for inbound mail are enabled automatically. Additional setup is required for signing outbound mail. This is optional but encouraged.

[docs-env-opendkim]: ../environment.md#enable_opendkim
[docs-env-rspamd]: ../environment.md#enable_rspamd

!!! warning "RSA Key Sizes >= 4096 Bit"

    Keys of 4096 bits could denied by some mail servers. According to [RFC 6376][rfc-6376] keys are [preferably between 512 and 2048 bits][github-issue-1854].

    [rfc-6376]: https://tools.ietf.org/html/rfc6376
    [github-issue-1854]: https://github.com/docker-mailserver/docker-mailserver/issues/1854

### OpenDKIM

OpenDKIM is currently enabled by default, but can be disabled with `ENABLE_OPENDKIM=0`.

#### Generating Keys

The command `docker exec <CONTAINER NAME> setup config dkim help` details supported config options, along with some examples.

DKIM signing requires a private key, while verification requires your DNS to be configured with the associated public key.

!!! example "Create a DKIM key (OpenDKIM)"

    This example requires:

    - You have [created at least one email account][docs-accounts-add].
    - Use your [volume for config][docs-volumes-config] (eg: `./docker-data/dms/config/:/tmp/docker-mailserver/`) to persist the DKIM key.
    
    Generate the DKIM files with:

    ```sh
    docker exec -ti <CONTAINER NAME> config dkim
    ```

    This has created your DKIM key and OpenDKIM config files.

    - `docker-mailserver` needs to be restarted. Outgoing mail will now be signed with your new DKIM key(s).
    - For a receiver to verify your DKIM key, you must also add the DKIM public key to your DNS.
    - You'll need to repeat this process if you add any new domains.

!!! note "LDAP accounts need to specify domains explicitly"

    The command is unable to infer the domains from LDAP user accounts, you must specify them:

    ```sh
    setup config dkim domain 'mail.example.com,mail.example.io'
    ```

!!! tip "Changing the key size"

    The private key presently defaults to RSA-4096. Some DNS services and clients are only compatible with a smaller size.

    You can override the default like so for 2048-bit keysize:

    ```sh
    setup config dkim keysize 2048
    ```

[docs-accounts-add]: ../user-management.md#adding-a-new-account
[docs-volumes-config]: ../advanced/optional-config.md

### Rspamd

Verifying a DKIM signature and signing an email are two different tasks. Rspamd differentiates between the two at a module level:

1. [Verifying signatures of inbound mail][rspamd-docs-dkim-checks] is enabled by default.
2. [Signing outbound mail][rspamd-docs-dkim-signing] needs additional setup.

By default, DMS offers no option to generate and configure signing e-mails with DKIM. This is because the parsing would be difficult. But don't worry: the process is relatively straightforward nevertheless. The [official Rspamd documentation for the DKIM signing module][rspamd-docs-dkim-signing] is pretty good. Basically, you need to

1. Go inside the container with `docker exec -ti <CONTAINER NAME> bash`
2. Run a command similar to `rspamadm dkim_keygen -s 'selector-name' -b 2048 -d example.com -k example.private > example.txt`, adjusted to your needs
3. Make sure to then persists the files `example.private` and `example.txt` (created in step 2) in the container (for example with a Docker bind mount)
4. Create a configuration for the DKIM signing module, i.e. a file called `dkim_signing.conf` that you mount to `/etc/rspamd/local.d/` or `/etc/rspamd/override.d/`. We provide example configurations down below. We recommend mounting this file into the container as well (as described [here](#manually)); do not use [`rspamd-modules.conf`](#with-the-help-of-a-custom-file) for this purpose.

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
    check_pubkey = true; # you wan't to use this in the beginning

    domain {
        example.com {
            path = "/path/to/example.private";
            selector = "selector-name";
        }
    }
    ```

    If you have multiple domains and you want to sign with the modern ED25519 elliptic curve but also with RSA (you will likely want to have RSA as a fallback!):

    ```cf
    # documentation: https://rspamd.com/doc/modules/dkim_signing.html

    enabled = true;

    sign_authenticated = true;
    sign_local = true;

    use_domain = "header";
    use_redis = false; # don't change unless Redis also provides the DKIM keys
    use_esld = true;
    check_pubkey = true;

    domain {
        example.com {
            selectors [
                {
                    path = "/path/to/com.example.rsa.private";
                    selector = "dkim-rsa";
                },
                {
                  path = /path/to/com.example.ed25519.private";
                  selector = "dkim-ed25519";
                }
          ]
        }
        example.org {
            selectors [
                {
                    path = "/path/to/org.example.rsa.private";
                    selector = "dkim-rsa";
                },
                {
                  path = "/path/to/org.example.ed25519.private";
                  selector = "dkim-ed25519";
                }
            ]
        }
    }
    ```

!!! bug "File Permissions & Signing Issues"

    Make sure the user `_rspamd` is able to go into the directory where you persist the (private) key files, and ensure it can read them! You can use `su -l _rspamd -s /bin/bash` to change to the `_rspamd` user and then navigate into the directory and read the files (e.g. with `cat`). If any errors occur, you know the permissions are not correct yet.

    When you set `check_pubkey = true;` in `dkim_signing.conf`, Rspamd will check the public key against your private key and emit a warning if there is a mismatch. Monitor the log file (`/var/log/supervisor/rspamd.log`) closely!

[rspamd-docs-dkim-checks]: https://www.rspamd.com/doc/modules/dkim.html
[rspamd-docs-dkim-signing]: https://www.rspamd.com/doc/modules/dkim_signing.html

### DNS Record { #dkim-dns }

When mail signed with your DKIM key is sent from your mail server, the receiver needs to check a DNS `TXT` record to verify the DKIM signature is trustworthy.

!!! example "Configuring DNS - DKIM record"

    When you generated your key in the previous step, the DNS data was saved into a file `<selector>.txt` (default: `mail.txt`). Use this content to update your [DNS via Web Interface][dns::example-webui] or directly editing your [DNS Zone file][dns::wikipedia-zonefile]:

    === "Web Interface"

        Create a new record:

        - **Type:** `TXT`
        - **Name:** should be your DKIM selector `<selector>._domainkey` (_default: `mail._domainkey`_)
        - **Value:** should use the content within `( ... )` (_see the info section below for advice on correct formatting_)
        - **TTL:** Use the default (_otherwise [3600 seconds is appropriate][dns::digicert-ttl]_)

    === "DNS Zone file"

        `<selector>.txt` is already formatted as a snippet for adding to your [DNS Zone file][dns::wikipedia-zonefile].

        Just copy/paste the file contents into your existing DNS zone. The `TXT` value has been split into separate strings every 255 characters for compatibility.

[dns::example-webui]: https://www.vultr.com/docs/introduction-to-vultr-dns/
[dns::digicert-ttl]: https://www.digicert.com/faq/dns/what-is-ttl
[dns::wikipedia-zonefile]: https://en.wikipedia.org/wiki/Zone_file

!!! info "`<selector>.txt` - Formatting the `TXT` value correctly"

    This file was generated for use within a [DNS zone file][dns::wikipedia-zonefile]. DNS `TXT` records values that are longer than 255 characters need to be split into multiple parts. This is why the public key has multiple parts wrapped within double-quotes between `(` and `)`.
    
    A DNS web-interface may handle this internally instead, while [others may not, but expect the input as a single line][dns-webui-dkim]_). You'll need to manually format the value as described below.

    Your DNS record file (eg: `mail.txt`) should look similar to this:

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
    $ dig +short TXT dkim-rsa._domainkey.example.com
    "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqQMMqhb1S52Rg7VFS3EC6JQIMxNDdiBmOKZvY5fiVtD3Z+yd9ZV+V8e4IARVoMXWcJWSR6xkloitzfrRtJRwOYvmrcgugOalkmM0V4Gy/2aXeamuiBuUc4esDQEI3egmtAsHcVY1XCoYfs+9VqoHEq3vdr3UQ8zP/l+FP5UfcaJFCK/ZllqcO2P1GjIDVSHLdPpRHbMP/tU1a9mNZ5QMZBJ/JuJK/s+2bp8gpxKn8rh1akSQjlynlV9NI+7J3CC7CUf3bGvoXIrb37C/lpJehS39" "KNtcGdaRufKauSfqx/7SxA0zyZC+r13f7ASbMaQFzm+/RRusTqozY/p/MsWx8QIDAQAB"
    ```

[cloudflare-dns-zonefile]: https://www.cloudflare.com/en-gb/learning/dns/glossary/dns-zone
[dns-webui-dkim]: https://serverfault.com/questions/763815/route-53-doesnt-allow-adding-dkim-keys-because-length-is-too-long

### Troubleshooting { #dkim-debug }

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
