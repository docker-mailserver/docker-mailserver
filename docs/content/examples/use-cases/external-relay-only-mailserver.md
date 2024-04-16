---
title: 'Use Cases | Use a public server for relaying between a private DMS instance'
hide:
  - toc
---

## Introduction

!!! info "Community contributed guide"

    Adapted into a guide from [this discussion](https://github.com/orgs/docker-mailserver/discussions/3965).

    **Requirements:**

    - A _public server_ with a static IP, like many VPS providers offer. It will only relay mail to DMS, no mail is stored on this system.
    - A _private server_ (eg: a local system at home) that will run DMS.
    - Both servers are connected to the same network via a VPN (_optional convenience for trust via the `mynetworks` setting_). We will assume below that the VPN is setup on `192.168.2.0/24`, with the _public server_ using `192.168.2.2` and the _private server_ using `192.168.2.3`.

The goal of this guide is to configure a _public server_ that can receive inbound mail and relay that over to DMS on a _private server_, which can likewise submit mail outbound through a _public server_ or service. The primary motivation is keep your mail storage private, instead of storing unencrypted on a VPS host disk.
  
## DNS setup

Follow our [standard guidance][docs::usage-dns-setup] for DNS setup.

!!! example "DNZ Zone file example"

    - A public reachable IP address of `11.22.33.44`
    - Mail for `@example.com` addreses has an MX record to `mail.example.com` which resolves to that _public server_ IP.
    - Set your A, MX and PTR records for the _public server_ as if it were running DMS.

    ```txt
    $ORIGIN example.com
    @     IN  A      123.123.123.123
    mail  IN  A      123.123.123.123

    ; mail server for example.com
    @     IN  MX  10 mail.example.com.
    ```

    SPF records should also be setup as you normally would for `mail.example.com`.

## Public Server (Basic Postfix setup)

You will need to install Postfix on your _public server_. The functionality that is needed for this setup is not yet implemented in DMS, so a vanilla Postfix will probably be easier to work with, especially since this server will only be used as an inbound and outbound relay.

It's necessary to adjust some settings afterwards.

???+ example "Postfix main config"

    Create or replace `/etc/postfix/main.cf` with this content:

    ```txt
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
    - For good measure also disable `local_recipient_maps`.
    - You should have a valid certificate configured for `mail.example.com`.

    !!! warning "Open relay"

        Please be aware that setting `mynetworks` to a public CIDR will leave you with an open relay. **Only** set it to the CIDR of your VPN beyond the localhost ranges.

!!! example "Route outbound mail through a separate transport"

    When mail arrives to the _public server_ for an `@example.com` address, we want to send it via the `relay` transport to our _private server_ over port 25 for delivery to DMS.

    [`transport_maps`][postfix-docs::transport_maps] is configured with a [`transport` table][postfix-docs::transport_table] file that matches recipient addresses and assigns a non-default transport. This setting has priority over [`relay_transport`][postfix-docs::relay_transport].

    Create `/etc/postfix/transport` with contents:

    ```txt
    example.com relay:[192.168.2.3]:25
    ```

    Other considerations:

    - If you have multiple domains, you can add them there too as separate lines.
    - If you use a smarthost add `* relay:[X.X.X.X]:port` to the bottom, eg `* relay:[relay1.org]:587`, which will relay everything outbound via this relay host.

    !!! tip

        Instead of a file, you could alternatively configure `main.cf` with `transport_maps = inline:{ example.com=relay:[192.168.2.3]:25 }`

!!! example "Configure recipient domains to relay mail"

    We want `example.com` to be relayed inbound and everything else relayed outbound.

    [`relay_domains`][postfix-docs::relay_domains] is configured with a file with a list of domains that should be relayed (one per line), the 2nd value is required but can be anything.

    Create `/etc/postfix/relay` with contents:

    ```txt
    example.com   OK
    *             OK
    ```

    !!! tip

        Instead of a file, you could alternatively configure `main.cf` with `relay_domains = example.com`.

Run `postmap /etc/postfix/transport` and `postmap /etc/postfix/relay` after creating or updating those files to make them compatible for Postfix to use.

## Private Server (Running DMS)

You can setup your DMS instance as you normally would.

- Be careful to not give it a hostname of `mail.example.com`. Instead use `internal-mail.example.com` or something similar.
- DKIM can be setup as usual since it considers checks whether the message body has been tampered with, which our public relay doesn't do. Set DKIM up for `mail.example.com`.

Next we need to configure our _private server_ to relay all outbound mail through the _public server_ (or a separate smarthost service). The setup is [similar to the default relay setup][docs::relay-host-details].

!!! example "Configure the relay host"

    Create `postfix-relaymap.cf` with contents:

    ```txt
    @example.com  [192.168.2.2]:25
    ```

    Meaning all mail sent outbound from `@example.com` addresses will be relayed through the _public server_ at the VPN IP.

    The _public server_ `mynetworks` setting from earlier trusts any mail received on port 25 from the VPN network, which is what allows the mail to be sent outbound when it'd otherwise be denied.

!!! example "Trust the _public server_"

    Create `postfix-main.cf` with contents:

    ```txt
    mynetworks = 192.168.2.0/24
    ```

    This will trust any connection from the VPN network to DMS, such as from the _public server_ when relaying mail over to DMS at the _private server_.

    This step is necessary to skip some security measures that DMS normally checks for, like verifying DNS records like SPF are valid. As the mail is being relayed, those checks would fail otherwise as the IP of your _public server_ would not be authorized to send mail on behalf of the sender address in mail being relayed.

!!! tip "Alternative to `mynetworks`"

    Instead of trusting connections by their IP with the `mynetworks` setting, those same security measures can be skipped for any authenticated deliveries to DMS over port 587 instead.

    This is a bit more work. `mynetworks` on the _public server_ config is for trusting DMS to send mail from the _private server_, thus you'll need to have that public Postfix service configured with a login account that DMS can use.
    
    On the DMS side, `postfix-sasl-password.cf` configures which credentials should be used for a SASL login address:

    ```txt
    @example.com user:secret
    ```

    You could also relay mail through SendGrid, AWS SES or similar instead of the _public server_ you're running, providing login credentials through the same `postfix-sasl-password.cf` file.

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
