---
title: 'Use Cases | Relay inbound and outbound mail for an internal DMS'
hide:
  - toc
---

## Introduction

!!! info "Community contributed guide"

    Adapted into a guide from [this discussion](https://github.com/orgs/docker-mailserver/discussions/3965).

    **Requirements:**

    - A _public server_ with a static IP, like many VPS providers offer. It will only relay mail to DMS, no mail is stored on this system.
    - A _private server_ (e.g.: a local system at home) that will run DMS.
    - Both servers are connected to the same network via a VPN (_optional convenience for trust via the `mynetworks` setting_).

    ---

    The guide below will assume the VPN is setup on `192.168.2.0/24` with:

    - The _public server_ is using `192.168.2.2`
    - The _private server_ is using `192.168.2.3`

The goal of this guide is to configure a _public server_ that can receive inbound mail and relay that over to DMS on a _private server_, which can likewise submit mail outbound through a _public server_ or service.

The primary motivation is to keep your mail storage private instead of storing it to disk unencrypted on a VPS host.

## DNS setup

Follow our [standard guidance][docs::usage-dns-setup] for DNS setup.

Set your A, MX and PTR records for the _public server_ as if it were running DMS.

!!! example "DNS Zone file example"
    
    For this guide, we assume DNS is configured with:

    - A public reachable IP address of `11.22.33.44`
    - Mail for `@example.com` addresses must have an MX record pointing to `mail.example.com`.
    - An A record for `mail.example.com` pointing to the IP address of your _public server_.

    ```txt
    $ORIGIN example.com
    @     IN  A      11.22.33.44
    mail  IN  A      11.22.33.44

    ; mail server for example.com
    @     IN  MX  10 mail.example.com.
    ```

    SPF records should also be set up as you normally would for `mail.example.com`.

## Public Server (Basic Postfix setup)

You will need to install Postfix on your _public server_. The functionality that is needed for this setup is not yet implemented in DMS, so a vanilla Postfix will probably be easier to work with, especially since this server will only be used as an inbound and outbound relay.

It's necessary to adjust some settings afterwards.

<!-- This empty quote block is purely for a visual border -->
!!! quote ""

    === "Postfix main config"

        ??? example "Create or replace `/etc/postfix/main.cf`"

            ```cf
            # See /usr/share/postfix/main.cf.dist for a commented, more complete version

            smtpd_banner = $myhostname ESMTP $mail_name (Debian/GNU)
            biff = no

            # appending .domain is the MUA's job.
            append_dot_mydomain = no

            # Uncomment the next line to generate "delayed mail" warnings
            #delay_warning_time = 4h

            # See http://www.postfix.org/COMPATIBILITY_README.html -- default to 3.6 on
            # fresh installs.
            compatibility_level = 3.6

            # TLS parameters
            smtpd_tls_cert_file=/etc/postfix/certificates/mail.example.com.crt
            smtpd_tls_key_file=/etc/postfix/certificates/mail.example.com.key
            smtpd_tls_security_level=may
            smtp_tls_CApath=/etc/ssl/certs
            smtp_tls_security_level=may
            smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

            alias_database = hash:/etc/aliases
            alias_maps = hash:/etc/aliases
            maillog_file = /var/log/postfix.log
            mailbox_size_limit = 0
            inet_interfaces = all
            inet_protocols = ipv4
            readme_directory = no
            recipient_delimiter = +

            # Customizations relevant to this guide:
            myhostname = mail.example.com
            myorigin = example.com
            mydestination = localhost
            mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 192.168.2.0/24
            smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
            transport_maps = hash:/etc/postfix/transport
            relay_domains = $mydestination, hash:/etc/postfix/relay

            # Disable local system accounts and delivery:
            local_recipient_maps =
            local_transport = error:local mail delivery is disabled
            ```

        Let's highlight some of the important parts:

        - Avoid including `mail.example.com` in `mydestination`, in fact you can just set `localhost` or nothing at all here as we want all mail to be relayed to our _private server_ (DMS).
        - `mynetworks` should contain your VPN network (_eg: `192.168.2.0/24` subnet_).
        - Important are `transport_maps = hash:/etc/postfix/transport` and `relay_domains = $mydestination, hash:/etc/postfix/relay`, with their file contents covered below.
        - For good measure, also disable `local_recipient_maps`.
        - You should have a valid certificate configured for `mail.example.com`.

        !!! warning "Open relay"

            Please be aware that setting `mynetworks` to a public CIDR will leave you with an open relay. **Only** set it to the CIDR of your VPN beyond the localhost ranges.

    === "Route outbound mail through a separate transport"

        When mail arrives to the _public server_ for an `@example.com` address, we want to send it via the `relay` transport to our _private server_ over port 25 for delivery to DMS.

        [`transport_maps`][postfix-docs::transport_maps] is configured with a [`transport` table][postfix-docs::transport_table] file that matches recipient addresses and assigns a non-default transport. This setting has priority over [`relay_transport`][postfix-docs::relay_transport].

        !!! example "Create `/etc/postfix/transport`"

            ```txt
            example.com relay:[192.168.2.3]:25
            ```

            **Other considerations:**

            - If you have multiple domains, you can add them here too (on separate lines).
            - If you use a smarthost add `* relay:[X.X.X.X]:port` to the bottom (eg: `* relay:[relay1.org]:587`), which will relay everything outbound via this relay host.

        !!! tip

            Instead of a file, you could alternatively configure `main.cf` with `transport_maps = inline:{ example.com=relay:[192.168.2.3]:25 }`

    === "Configure recipient domains to relay mail"

        We want `example.com` to be relayed inbound and everything else relayed outbound.

        [`relay_domains`][postfix-docs::relay_domains] is configured with a file with a list of domains that should be relayed (one per line), the 2nd value is required but can be anything.

        !!! example "Create `/etc/postfix/relay`"

            ```txt
            example.com   OK
            ```

        !!! tip

            Instead of a file, you could alternatively configure `main.cf` with `relay_domains = example.com`.

!!! note "Files configured with `hash:` table type must run `postmap` to apply changes"

    Run `postmap /etc/postfix/transport` and `postmap /etc/postfix/relay` after creating or updating either of these files, this processes them into a separate file for Postfix to use.

## Private Server (Running DMS)

You can set up your DMS instance as you normally would.

- Be careful not to give it a hostname of `mail.example.com`. Instead, use `internal-mail.example.com` or something similar.
- DKIM can be setup as usual since it considers checks whether the message body has been tampered with, which our public relay doesn't do. Set DKIM up for `mail.example.com`.

Next, we need to configure our _private server_ to relay all outbound mail through the _public server_ (or a separate smarthost service). The setup is [similar to the default relay setup][docs::relay-host-details].

<!-- This empty quote block is purely for a visual border -->
!!! quote ""

    === "Configure the relay host"

        !!! example "Create `postfix-relaymap.cf`"

            ```txt
            @example.com  [192.168.2.2]:25
            ```

        Meaning all mail sent outbound from `@example.com` addresses will be relayed through the _public server_ at that VPN IP.

        The _public server_ `mynetworks` setting from earlier trusts any mail received on port 25 from the VPN network, which is what allows the mail to be sent outbound when it'd otherwise be denied.

    === "Trust the _public server_"

        !!! example "Create `postfix-main.cf`"

            ```txt
            mynetworks = 192.168.2.0/24
            ```

        This will trust any connection from the VPN network to DMS, such as from the _public server_ when relaying mail over to DMS at the _private server_.

        This step is necessary to skip some security measures that DMS normally checks for, like verifying DNS records like SPF are valid. As the mail is being relayed, those checks would fail otherwise as the IP of your _public server_ would not be authorized to send mail on behalf of the sender address in mail being relayed.

        ??? tip "Alternative to `mynetworks` setting"

            Instead of trusting connections by their IP with the `mynetworks` setting, those same security measures can be skipped for any authenticated deliveries to DMS over port 587 instead.

            This is a bit more work. `mynetworks` on the _public server_ `main.cf` Postfix config is for trusting DMS when it sends mail from the _private server_, thus you'll need to have that public Postfix service configured with a login account that DMS can use.

            On the _private server_, DMS needs to know the credentials for that login account, that is handled with `postfix-sasl-password.cf`:

            ```txt
            @example.com user:secret
            ```

            You could also relay mail through SendGrid, AWS SES or similar instead of the _public server_ you're running to receive mail from. Login credentials for those relay services are provided via the same `postfix-sasl-password.cf` file.

            ---

            Likewise for the _public server_ to send mail to DMS, it would need to be configured to relay mail with credentials too, removing the need for `mynetworks` on the DMS `postfix-main.cf` config.

            The extra effort to require authentication instead of blind trust of your private subnet can be beneficial at reducing the impact of a compromised system or service on that network that wasn't expected to be permitted to send mail.

## IMAP / POP3

IMAP and POP3 need to point towards your _private server_, since that is where the mailboxes are located, which means you need to have a way for your MUA to connect to it.

[docs::usage-dns-setup]: ../../usage.md#minimal-dns-setup
[docs::relay-host-details]: ../../config/advanced/mail-forwarding/relay-hosts.md#technical-details
[postfix-docs::relay_domains]: https://www.postfix.org/postconf.5.html#relay_domains
[postfix-docs::relay_transport]: https://www.postfix.org/postconf.5.html#relay_transport
[postfix-docs::transport_maps]: https://www.postfix.org/postconf.5.html#transport_maps
[postfix-docs::transport_table]: https://www.postfix.org/transport.5.html
