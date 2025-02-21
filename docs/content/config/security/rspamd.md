---
title: 'Security | Rspamd'
---

## About

Rspamd is a ["fast, free and open-source spam filtering system"][rspamd-web]. DMS integrates Rspamd like any other service. We provide a basic but easy to maintain setup of Rspamd.

If you want to take a look at the default configuration files for Rspamd that DMS adds, navigate to [`target/rspamd/` inside the repository][dms-repo::default-rspamd-configuration]. Please consult the [section "The Default Configuration"](#the-default-configuration) section down below for a written overview.

### Enable Rspamd

Rspamd is presently opt-in for DMS, but intended to become the default anti-spam service in a future release.

DMS offers two anti-spam solutions:

- Legacy (_Amavis, SpamAssassin, OpenDKIM, OpenDMARC_)
- Rspamd (_Provides equivalent features of software from the legacy solution_)

While you could configure Rspamd to only replace some of the legacy services, it is advised to only use Rspamd with the legacy services disabled.

!!! example "Switch to Rspamd"

    To use Rspamd add the following ENV config changes:
    
    ```env
    ENABLE_RSPAMD=1
    
    # Rspamd replaces the functionality of all these anti-spam services, disable them:
    ENABLE_OPENDKIM=0
    ENABLE_OPENDMARC=0
    ENABLE_POLICYD_SPF=0
    ENABLE_AMAVIS=0
    ENABLE_SPAMASSASSIN=0
    # Greylisting is opt-in, if you had enabled Postgrey switch to the Rspamd equivalent:
    ENABLE_POSTGREY=0
    RSPAMD_GREYLISTING=1
    
    # Optional: Add anti-virus support with ClamAV (compatible with Rspamd):
    ENABLE_CLAMAV=1
    ```

!!! info "Relevant Environment Variables"

    The following environment variables are related to Rspamd:
    
    1. [`ENABLE_RSPAMD`](../environment.md#enable_rspamd)
    2. [`ENABLE_RSPAMD_REDIS`](../environment.md#enable_rspamd_redis)
    3. [`RSPAMD_CHECK_AUTHENTICATED`](../environment.md#rspamd_check_authenticated)
    4. [`RSPAMD_GREYLISTING`](../environment.md#rspamd_greylisting)
    5. [`RSPAMD_HFILTER`](../environment.md#rspamd_hfilter)
    6. [`RSPAMD_HFILTER_HOSTNAME_UNKNOWN_SCORE`](../environment.md#rspamd_hfilter_hostname_unknown_score)
    7. [`RSPAMD_LEARN`](../environment.md#rspamd_learn)
    8. [`SPAM_SUBJECT`](../environment.md#spam_subject)
    9. [`MOVE_SPAM_TO_JUNK`][docs::spam-to-junk]
    10. [`MARK_SPAM_AS_READ`](../environment.md#mark_spam_as_read)

## Overview of Rspamd support

### Mode of Operation

!!! note "Attention"

    Read this section carefully if you want to understand how Rspamd is integrated into DMS and how it works (on a surface level).

Rspamd is integrated as a milter into DMS. When enabled, Postfix's `main.cf` configuration file includes the parameter `rspamd_milter = inet:localhost:11332`, which is added to `smtpd_milters`. As a milter, Rspamd can inspect incoming and outgoing e-mails.

Each mail is assigned what Rspamd calls symbols: when an e-mail matches a specific criterion, the e-mail receives a symbol. Afterward, Rspamd applies a _spam score_ (as usual with anti-spam software) to the e-mail.

- The score itself is calculated by adding the values of the individual symbols applied earlier. The higher the spam score is, the more likely the e-mail is spam.
- Symbol values can be negative (i.e., these symbols indicate the mail is legitimate, maybe because [SPF and DKIM][docs::dkim-dmarc-spf] are verified successfully). On the other hand, symbol scores can be positive (i.e., these symbols indicate the e-mail is spam, perhaps because the e-mail contains numerous links).

Rspamd then adds (a few) headers to the e-mail based on the spam score. Most important is `X-Spamd-Result`, which contains an overview of which symbols were applied. It could look like this:

```txt
X-Spamd-Result     default: False [-2.80 / 11.00]; R_SPF_NA(1.50)[no SPF record]; R_DKIM_ALLOW(-1.00)[example.com:s=dtag1]; DWL_DNSWL_LOW(-1.00)[example.com:dkim]; RWL_AMI_LASTHOP(-1.00)[192.0.2.42:from]; DMARC_POLICY_ALLOW(-1.00)[example.com,none]; RWL_MAILSPIKE_EXCELLENT(-0.40)[192.0.2.42:from]; FORGED_SENDER(0.30)[noreply@example.com,some-reply-address@bounce.example.com]; RCVD_IN_DNSWL_LOW(-0.10)[192.0.2.42:from]; MIME_GOOD(-0.10)[multipart/mixed,multipart/related,multipart/alternative,text/plain]; MIME_TRACE(0.00)[0:+,1:+,2:+,3:+,4:~,5:~,6:~]; RCVD_COUNT_THREE(0.00)[3]; RCPT_COUNT_ONE(0.00)[1]; REPLYTO_DN_EQ_FROM_DN(0.00)[]; ARC_NA(0.00)[]; TO_MATCH_ENVRCPT_ALL(0.00)[]; RCVD_TLS_LAST(0.00)[]; DKIM_TRACE(0.00)[example.com:+]; HAS_ATTACHMENT(0.00)[]; TO_DN_NONE(0.00)[]; FROM_NEQ_ENVFROM(0.00)[noreply@example.com,some-reply-address@bounce.example.com]; FROM_HAS_DN(0.00)[]; REPLYTO_DOM_NEQ_FROM_DOM(0.00)[]; PREVIOUSLY_DELIVERED(0.00)[receiver@anotherexample.com]; ASN(0.00)[asn:3320, ipnet:192.0.2.0/24, country:DE]; MID_RHS_MATCH_FROM(0.00)[]; MISSING_XM_UA(0.00)[]; HAS_REPLYTO(0.00)[some-reply-address@dms-reply.example.com]
```

And then there is a corresponding `X-Rspamd-Action` header, which shows the overall result and the action that is taken. In our example, it would be:

```txt
X-Rspamd-Action    no action
```

Since the score is `-2.80`, nothing will happen and the e-mail is not classified as spam. Our custom [`actions.conf`][dms-repo::rspamd-actions-config] defines what to do at certain scores:

1. At a score of 4, the e-mail is to be _greylisted_;
2. At a score of 6, the e-mail is _marked with a header_ (`X-Spam: Yes`);
3. At a score of 11, the e-mail is outright _rejected_.

---

There is more to spam analysis than meets the eye: we have not covered the [Bayes training and filters][rspamd-docs::bayes] here, nor have we discussed [Sieve rules for e-mails that are marked as spam][docs::spam-to-junk].

Even the calculation of the score with the individual symbols has been presented to you in a simplified manner. But with the knowledge from above, you're equipped to read on and use Rspamd confidently. Keep on reading to understand the integration even better - you will want to know about your anti-spam software, not only to keep the bad e-mail out, but also to make sure the good e-mail arrive properly!

### Workers

The proxy worker operates in [self-scan mode][rspamd-docs::proxy-self-scan-mode]. This simplifies the setup as we do not require a normal worker. You can easily change this though by [overriding the configuration by DMS](#providing-custom-settings-overriding-settings).

DMS does not set a default password for the controller worker. You may want to do that yourself. In setups where you already have an authentication provider in front of the Rspamd webpage, you may want to [set the `secure_ip ` option to `"0.0.0.0/0"` for the controller worker](#with-the-help-of-a-custom-file) to disable password authentication inside Rspamd completely.

### Persistence with Redis

When Rspamd is enabled, we implicitly also start an instance of Redis in the container:

- Redis is configured to persist its data via RDB snapshots to disk in the directory `/var/lib/redis` (_or the [`/var/mail-state/`][docs::dms-volumes-state] volume when present_).
- With the volume mount, the snapshot will restore the Redis data across container updates, and provide a way to keep a backup.
- Without a volume mount a containers internal state will persist across restarts until the container is recreated due to changes like ENV or upgrading the image for the container.

Redis uses `/etc/redis/redis.conf` for configuration:

- We adjust this file when enabling the internal Redis service.
- If you have an external instance of Redis to use, the internal Redis service can be opt-out via setting the ENV [`ENABLE_RSPAMD_REDIS=0`][docs::env::enable-redis] (_link also details required changes to the DMS Rspamd config_).

If you are interested in using Valkey instead of Redis, please refer to [this guidance][gh-dms::guide::valkey].

### Web Interface

Rspamd provides a [web interface][rspamd-docs::web-ui], which contains statistics and data Rspamd collects. The interface is enabled by default and reachable on port 11334.

![Rspamd Web Interface](https://rspamd.com/img/webui.png)

To use the web interface you will need to configure a password, [otherwise you won't be able to log in][rspamd-docs::web-ui::password].

??? example "Set a custom password"

    Add this line to [your Rspamd `custom-commands.conf` config](#with-the-help-of-a-custom-file) which sets the `password` option of the _controller worker_:

    ```
    set-option-for-controller password "your hashed password here"
    ```

    The password hash can be generated via the `rspamadm pw` command:

    ```bash
    docker exec -it <CONTAINER_NAME> rspamadm pw
    ```

    ---

    **Related:** A minimal Rspamd `compose.yaml` [example with a reverse-proxy for web access][gh-dms::guide::rspamd-web].

### DNS

DMS does not supply custom values for DNS servers (to Rspamd). If you need to use custom DNS servers, which could be required when using [DNS-based deny/allowlists](#rbls-real-time-blacklists-dnsbls-dns-based-blacklists), you need to adjust [`options.inc`][rspamd-docs::config::global] yourself. Make sure to also read our [FAQ page on DNS servers][docs::faq::dns-servers].

!!! warning

    Rspamd heavily relies on a properly working DNS server that it can use to resolve DNS queries. If your DNS server is misconfigured, you will encounter issues when Rspamd queries DNS to assess if mail is spam. Legitimate mail is then unintentionally marked as spam or worse, rejected entirely.

    When Rspamd is deciding if mail is spam, it will check DNS records for SPF, DKIM and DMARC. Each of those has an associated symbol for DNS temporary errors with a non-zero weight assigned. That weight contributes towards the spam score assessed by Rspamd which is normally desirable - provided your network DNS is functioning correctly, otherwise when DNS is broken all mail is biased towards spam due to these failed DNS lookups.

!!! danger

    While we do not provide values for custom DNS servers by default, we set `soft_reject_on_timeout = true;` by default. This setting will cause a soft reject if a task (presumably a DNS request) timeout takes place.

    This setting is enabled to not allow spam to proceed just because DNS requests did not succeed. It could deny legitimate e-mails to pass though too in case your DNS setup is incorrect or not functioning properly.

### Logs

You can find the Rspamd logs at `/var/log/mail/rspamd.log`, and the corresponding logs for [Redis](#persistence-with-redis), if it is enabled, at `/var/log/supervisor/rspamd-redis.log`. We recommend inspecting these logs (with `docker exec -it <CONTAINER NAME> less /var/log/mail/rspamd.log`) in case Rspamd does not work as expected.

### Modules

You can find a list of all Rspamd modules [on their website][rspamd-docs::modules].

#### Disabled By Default

DMS disables certain modules (`clickhouse`, `elastic`, `neural`, `reputation`, `spamassassin`, `url_redirector`, `metric_exporter`) by default. We believe these are not required in a standard setup, and they would otherwise needlessly use system resources.

#### Anti-Virus (ClamAV)

You can choose to enable ClamAV, and Rspamd will then use it to check for viruses. Just set the environment variable `ENABLE_CLAMAV=1`.

#### RBLs (Real-time Blacklists) / DNSBLs (DNS-based Blacklists)

The [RBL module][rspamd-docs::modules::rbl] is enabled by default. As a consequence, Rspamd will perform DNS lookups to various blacklists. Whether an RBL or a DNSBL is queried depends on where the domain name was obtained: RBL servers are queried with IP addresses extracted from message headers, DNSBL server are queried with domains and IP addresses extracted from the message body ([source][www::rbl-vs-dnsbl]).

!!! danger "Rspamd and DNS Block Lists"

    When the RBL module is enabled, Rspamd will do a variety of DNS requests to (amongst other things) DNSBLs. There are a variety of issues involved when using DNSBLs. Rspamd will try to mitigate some of them by properly evaluating all return codes. This evaluation is a best effort though, so if the DNSBL operators change or add return codes, it may take a while for Rspamd to adjust as well.

    If you want to use DNSBLs, **try to use your own DNS resolver** and make sure it is set up correctly, i.e. it should be a non-public & **recursive** resolver. Otherwise, you might not be able ([see this Spamhaus post][spamhaus::faq::dnsbl-usage]) to make use of the block lists.

## Providing Custom Settings & Overriding Settings

!!! info "Rspamd config overriding precedence"

    Rspamd has a layered approach for configuration with [`local.d` and `override.d` config directories][rspamd-docs::config-directories].

    - DMS [extends the Rspamd default configs via `/etc/rspamd/local.d/`][dms-repo::default-rspamd-configuration].
    - User config changes should be handled separately as overrides via the [DMS Config Volume][docs::dms-volumes-config] (`docker-data/dms/config/`) with either:
        - `./rspamd/override.d/` - Config files placed here are copied to `/etc/rspamd/override.d/` during container startup.
        - [`./rspamd/custom-commands.conf`](#with-the-help-of-a-custom-file) - Applied after copying any provided configs from `rspamd/override.d/` (DMS Config volume) to `/etc/rspamd/override.d/`.

!!! abstract "Reference docs for Rspamd config"

    - [Config Overview][rspamd-docs::config::overview], [Quickstart guide][rspamd-docs::config::quickstart], and [Config Syntax (UCL)][rspamd-docs::config::ucl-syntax]
    - Global Options ([`options.inc`][rspamd-docs::config::global])
    - [Workers][rspamd-docs::config::workers] ([`worker-controller.inc`][rspamd-docs::config::worker-controller], [`worker-proxy.inc`][rspamd-docs::config::worker-proxy])
    - [Modules][rspamd-docs::modules] (_view each module page for their specific config options_)

!!! tip "View rendered config"

    `rspamadm configdump` will output the full rspamd configuration that is used should you need it for troubleshooting / inspection.

    - You can also see which modules are enabled / disabled via `rspamadm configdump --modules-state`
    - Specific config sections like `dkim` or `worker` can also be used to filter the output to just those sections: `rspamadm configdump dkim worker`
    - Use `--show-help` to include inline documentation for many settings.

### Using `custom-commands.conf` { #with-the-help-of-a-custom-file }

For convenience DMS provides a single config file that will directly create or modify multiple configs at `/etc/rspamd/override.d/`. This is handled as the final rspamd configuration step during container startup.

DMS will apply this config when you provide `rspamd/custom-commands.conf` in your DMS Config volume. Configure it with directive lines as documented below.

!!! note "Only use this feature for `option = value` changes"

    `custom-commands.conf` is only suitable for adding or replacing simple `option = value` settings for configs at `/etc/rspamd/override.d/`.
  
    - New settings are appended to the associated config file.
    - When replacing an existing setting in an override config, that setting may be any matching line (_allowing for nested scopes, instead of only top-level keys_).
  
    Any changes involving more advanced [UCL config syntax][rspamd-docs::config::ucl-syntax] should instead add UCL config files directly to `rspamd/override.d/` (_in the DMS Config volume_).

!!! info "`custom-commands.conf` syntax"

    There are 7 directives available to manage custom Rspamd configurations. Add these directive lines into `custom-commands.conf`, they will be processed sequentially.

    **Directives:**

    ```txt
    # For /etc/rspamd/override.d/{options.inc,worker-controller.inc,worker-proxy}.inc
    set-common-option         <OPTION NAME> <OPTION VALUE>
    set-option-for-controller <OPTION NAME> <OPTION VALUE>
    set-option-for-proxy      <OPTION NAME> <OPTION VALUE>

    # For /etc/rspamd/override.d/<MODULE NAME>.conf
    enable-module         <MODULE NAME>
    disable-module        <MODULE NAME>
    set-option-for-module <MODULE NAME> <OPTION NAME> <OPTION VALUE>

    # For /etc/rspamd/override.d/<FILENAME>
    add-line <FILENAME> <CONTENT>
    ```

    **Syntax:**

    - Blank lines are ok.
    - `#` at the start of a line represents a comment for adding notes.
    - `<OPTION VALUE>` and `<CONTENT>` will contain the remaining content of their line, any preceding inputs are delimited by white-space.

    ---

    ??? note "`<MODULE NAME>` can also target non-module configs"

        An example is the `statistics` module, which has config to import a separate file (`classifier-bayes.conf`) for easier overrides to this section of the module config.

??? example

    ```conf title="rspamd/custom-commands.conf"
    # If you're confident you've properly secured access to the rspamd web service/API (Default port: 11334)
    # with your own auth layer (eg: reverse-proxy) you can bypass rspamd requiring credentials:
    # https://rspamd.com/doc/workers/controller.html#controller-configuration
    set-option-for-controller secure_ip "0.0.0.0/0"

    # Some settings aren't documented well, you may find them in snippets or Rspamds default config files:
    # https://rspamd.com/doc/tutorials/quickstart.html#using-of-milter-protocol-for-rspamd--16
    # /etc/rspamd/worker-proxy.inc
    set-option-for-proxy reject_message "Rejected - Detected as spam"

    # Equivalent to the previous example, but `add-line` is more verbose:
    add-line worker-proxy.inc reject_message = "Rejected - Detected as spam"

    # Enable Bayes auto-learning feature to classify spam based on Rspamd action/score results:
    # NOTE: The statistics module imports a separate file for classifier-bayes config
    # https://rspamd.com/doc/configuration/statistic.html#autolearning
    set-option-for-module classifier-bayes autolearn true

    # Disable the `chartable` module:
    # https://rspamd.com/doc/modules/chartable.html
    disable-module chartable
    ```

## Advanced Configuration

### DKIM Signing

There is a dedicated [section for setting up DKIM with Rspamd in our documentation][docs::dkim-with-rspamd].

### ARC (Authenticated Received Chain)

[ARC][wikipedia::arc] support in DMS is opt-in via config file. [Enable the ARC Rspamd module][rspamd-docs::arc] by creating a config file at `docker-data/dms/config/rspamd/override.d/arc.conf`.

!!! example

    For each mail domain you have DMS manage, add the equivalent `example.com` sub-section to `domain` and adjust the `path` + `selector` fields as necessary.

    ```conf title="rspamd/override.d/arc.conf"
    sign_local = true;
    sign_authenticated = true;

    domain {
        example.com {
            path = "/tmp/docker-mailserver/rspamd/dkim/rsa-2048-mail-example.private.txt";
            selector = "mail";
        }
    }
    ```

!!! tip "Using a common keypair"

    As with DKIM, the keypair can be shared across your configured domains.

    Your ARC config can share the same DKIM private key + selector (_with associated DNS record for the public key_).

### _Abusix_ Integration

This subsection provides information about the integration of [Abusix][abusix-web], "a set of blocklists that work as an additional email security layer for your existing mail environment". The setup is straight-forward and well documented:

1. [Create an account][abusix-web::register]
2. Retrieve your API key
3. Navigate to the ["Getting Started" documentation for Rspamd][abusix-docs::rspamd-integration] and follow the steps described there
4. Make sure to change `<APIKEY>` to your private API key

We recommend mounting the files directly into the container, as they are rather big and not manageable with our [`custom-command.conf` script](#with-the-help-of-a-custom-file). If mounted to the correct location, Rspamd will automatically pick them up.

While _Abusix_ can be integrated into Postfix, Postscreen and a multitude of other software, we recommend integrating _Abusix_ only into a single piece of software running in your mail server - everything else would be excessive and wasting queries. Moreover, we recommend the integration into suitable filtering software and not Postfix itself, as software like Postscreen or Rspamd can properly evaluate the return codes and other configuration.

[rspamd-web]: https://rspamd.com/
[rspamd-docs::bayes]: https://rspamd.com/doc/configuration/statistic.html
[rspamd-docs::proxy-self-scan-mode]: https://rspamd.com/doc/workers/rspamd_proxy.html#self-scan-mode
[rspamd-docs::web-ui]: https://rspamd.com/webui/
[rspamd-docs::web-ui::password]: https://www.rspamd.com/doc/tutorials/quickstart.html#setting-the-controller-password
[rspamd-docs::modules]: https://rspamd.com/doc/modules/
[rspamd-docs::modules::rbl]: https://rspamd.com/doc/modules/rbl.html
[rspamd-docs::config-directories]: https://rspamd.com/doc/faq.html#what-are-the-locald-and-overrided-directories
[rspamd-docs::config::ucl-syntax]: https://rspamd.com/doc/configuration/ucl.html
[rspamd-docs::config::overview]: https://rspamd.com/doc/configuration/index.html
[rspamd-docs::config::quickstart]: https://rspamd.com/doc/tutorials/quickstart.html#configuring-rspamd
[rspamd-docs::config::global]: https://rspamd.com/doc/configuration/options.html
[rspamd-docs::config::workers]: https://rspamd.com/doc/workers/
[rspamd-docs::config::worker-controller]: https://rspamd.com/doc/workers/controller.html
[rspamd-docs::config::worker-proxy]: https://rspamd.com/doc/workers/rspamd_proxy.html

[wikipedia::arc]: https://en.wikipedia.org/wiki/Authenticated_Received_Chain
[rspamd-docs::arc]: https://rspamd.com/doc/modules/arc.html

[www::rbl-vs-dnsbl]: https://forum.eset.com/topic/25277-dnsbl-vs-rbl-mail-security/#comment-119818
[abusix-web]: https://abusix.com/
[abusix-web::register]: https://app.abusix.com/
[abusix-docs::rspamd-integration]: https://abusix.com/docs/rspamd/
[spamhaus::faq::dnsbl-usage]: https://www.spamhaus.org/faq/section/DNSBL%20Usage#365

[dms-repo::rspamd-actions-config]: https://github.com/docker-mailserver/docker-mailserver/tree/v15.0.0/target/rspamd/local.d/actions.conf
[dms-repo::default-rspamd-configuration]: https://github.com/docker-mailserver/docker-mailserver/tree/v15.0.0/target/rspamd
[gh-dms::guide::valkey]: https://github.com/docker-mailserver/docker-mailserver/issues/4001#issuecomment-2652596692
[gh-dms::guide::rspamd-web]: https://github.com/orgs/docker-mailserver/discussions/4269#discussioncomment-11329588

[docs::env::enable-redis]: ../environment.md#enable_rspamd_redis
[docs::spam-to-junk]: ../environment.md#move_spam_to_junk
[docs::dkim-dmarc-spf]: ../best-practices/dkim_dmarc_spf.md
[docs::dkim-with-rspamd]: ../best-practices/dkim_dmarc_spf.md#dkim

[docs::dms-volumes-config]: ../advanced/optional-config.md#volumes-config
[docs::dms-volumes-state]: ../advanced/optional-config.md#volumes-state

[docs::faq::dns-servers]: ../../faq.md#what-about-dns-servers
