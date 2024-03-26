---
title: 'Mail Forwarding | GMAIL SMTP'
---

[GMAIL SMTP (Simple Message Transport Protocol)][gmail-smtp] provides a simple way for cloud based applications to send and receive email.

!!! example "Configuration via ENV"

    [Configure a relay host in DMS][docs::relay] to forward all your mail through GMAIL SMTP:

    - `RELAY_HOST` should match your [SMTP Server Endpoint][gmail-smtp::relay-host].
    - `RELAY_PORT` should be set to [one of the supported Gmail SMTP ports][gmail-smtp::relay-port] (_eg: 587 for STARTTLS_).
    - `RELAY_USER` and `RELAY_PASSWORD` should be set to your [Gmail Account ID][gmail-smtp::account-id].

    ```env
    RELAY_HOST=smtp.gmail.com
    RELAY_PORT=587
    # Alternative to RELAY_HOST + RELAY_PORT which is compatible with LDAP:
    DEFAULT_RELAY_HOST=[smtp.gmail.com]:587

    RELAY_USER=someone@gmail.com
    RELAY_PASSWORD=xxx
    ```

!!! warning "Process of providing RELAY_PASSWORD"

    You should use your [2-step verification app password][gmail-smtp::2-step-password], **not** your gmail account password.
    `setup relay add-auth` is a better alternative, which manages the credentials via a config file.
    
!!! tip

    If you have set up GMAIL SMTP, you can Filter messages for spam and viruses before they reach external recipients
    and also apply email security and advanced Gmail settings to outgoing messages.

!!! note "Verify the relay host is configured correctly"

    To verify proper operation, send an email to some external account of yours and inspect the mail headers.
    You will also see the connection to GMAIL SMTP in the mail logs:

    ```log
    postfix/smtp[910]: Trusted TLS connection established to smtp.gmail.com[64.233.188.109]:587:
      TLSv1.3 with cipher TLS_AES_256_GCM_SHA384 (256/256 bits)
    postfix/smtp[910]: 4BCB547D9D: to=&lt;someone@gmail.com&gt;, relay=smtp.gmail.com[64.233.188.109]:587,
      delay=2.9, delays=0.01/0.02/1.7/1.2, dsn=2.0.0, status=sent (250 2.0.0 OK  17... - gsmtp)
    ```

[docs::relay]: ./relay-hosts.md
[gmail-smtp]: https://support.google.com/a/answer/2956491?sjid=10042458694956130936-AP
[gmail-smtp::relay-host]: https://support.google.com/a/answer/176600
[gmail-smtp::relay-port]: https://support.google.com/a/answer/2956491
[gmail-smtp::account-id]: https://myaccount.google.com/security?gar=1
[gmail-smtp::2-step-password]: https://support.google.com/accounts/answer/185833
