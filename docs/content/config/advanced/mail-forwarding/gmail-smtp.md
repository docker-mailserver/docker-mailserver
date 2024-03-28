---
title: 'Mail Forwarding | Configure Gmail as a relay host'
---

This page provides a guide for configuring DMS to use [GMAIL as an SMTP relay host][gmail-smtp].

!!! example "Configuration via ENV"

    [Configure a relay host in DMS][docs::relay]. This example shows how the related ENV settings map to the Gmail service config:

    - `RELAY_HOST` should be configured as [advised by Gmail][gmail-smtp::relay-host], there are two SMTP endpoints to choose:
        - `smtp.gmail.com` (_for a personal Gmail account_)
        - `smtp-relay.gmail.com` (_when using Google Workspace_)
    - `RELAY_PORT` should be set to [one of the supported Gmail SMTP ports][gmail-smtp::relay-port] (_eg: 587 for STARTTLS_).
    - `RELAY_USER` should be your gmail address (`user@gmail.com`).
    - `RELAY_PASSWORD` should be your [App Password][gmail-smtp::app-password], **not** your personal gmail account password.

    ```env
    RELAY_HOST=smtp.gmail.com
    RELAY_PORT=587
    # Alternative to RELAY_HOST + RELAY_PORT which is compatible with LDAP:
    DEFAULT_RELAY_HOST=[smtp.gmail.com]:587

    RELAY_USER=username@gmail.com
    RELAY_PASSWORD=secret
    ```

!!! tip
    
    - As per our main [relay host docs page][docs::relay], you may prefer to configure your credentials via `setup relay add-auth` instead of the `RELAY_USER` + `RELAY_PASSWORD` ENV.
    - If you configure for `smtp-relay.gmail.com`, the `DEFAULT_RELAY_HOST` ENV should be all you need as shown in the above example. Credentials can be optional when using Google Workspace (`smtp-relay.gmail.com`), which supports restricting connections to trusted IP addresses.

!!! note "Verify the relay host is configured correctly"

    To verify proper operation, send an email to an external account of yours and inspect the mail headers.

    You will also see the connection to the Gmail relay host (`smtp.gmail.com`) in the mail logs:

    ```log
    postfix/smtp[910]: Trusted TLS connection established to smtp.gmail.com[64.233.188.109]:587:
      TLSv1.3 with cipher TLS_AES_256_GCM_SHA384 (256/256 bits)
    postfix/smtp[910]: 4BCB547D9D: to=<username@gmail.com>, relay=smtp.gmail.com[64.233.188.109]:587,
      delay=2.9, delays=0.01/0.02/1.7/1.2, dsn=2.0.0, status=sent (250 2.0.0 OK  17... - gsmtp)
    ```

[docs::relay]: ./relay-hosts.md
[gmail-smtp]: https://support.google.com/a/answer/2956491
[gmail-smtp::relay-host]: https://support.google.com/a/answer/176600
[gmail-smtp::relay-port]: https://support.google.com/a/answer/2956491
[gmail-smtp::app-password]: https://support.google.com/accounts/answer/185833
