---
title: 'Mail Forwarding | AWS SES'
---

[Amazon SES (Simple Email Service)][aws-ses] provides a simple way for cloud based applications to send and receive email.

!!! example "Configuration via ENV"

    [Configure a relay host in DMS][docs::relay] to forward all your mail through AWS SES:

    - `RELAY_HOST` should match your [AWS SES region][aws-ses::region].
    - `RELAY_PORT` should be set to [one of the supported AWS SES SMTP ports][aws-ses::smtp-ports] (_eg: 587 for STARTTLS_).
    - `RELAY_USER` and `RELAY_PASSWORD` should be set to your [Amazon SES SMTP credentials][aws-ses::credentials].

    ```env
    RELAY_HOST=email-smtp.us-west-2.amazonaws.com
    RELAY_PORT=587
    # Alternative to RELAY_HOST + RELAY_PORT which is compatible with LDAP:
    DEFAULT_RELAY_HOST=[email-smtp.us-west-2.amazonaws.com]:587

    RELAY_USER=aws-user
    RELAY_PASSWORD=secret
    ```

!!! tip

    If you have set up [AWS Easy DKIM][aws-ses::easy-dkim], you can safely skip setting up DKIM as AWS SES will take care of signing your outbound mail.

!!! note "Verify the relay host is configured correctly"

    To verify proper operation, send an email to some external account of yours and inspect the mail headers.

    You will also see the connection to SES in the mail logs:

    ```log
    postfix/smtp[692]: Trusted TLS connection established to email-smtp.us-west-1.amazonaws.com[107.20.142.169]:25:
      TLSv1.2 with cipher ECDHE-RSA-AES256-GCM-SHA384 (256/256 bits)
    postfix/smtp[692]: 8C82A7E7: to=<someone@example.com>, relay=email-smtp.us-west-1.amazonaws.com[107.20.142.169]:25,
      delay=0.35, delays=0/0.02/0.13/0.2, dsn=2.0.0, status=sent (250 Ok 01000154dc729264-93fdd7ea-f039-43d6-91ed-653e8547867c-000000)
    ```

[docs::relay]: ./relay-hosts.md
[aws-ses]: https://aws.amazon.com/ses/
[aws-ses::credentials]: https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html
[aws-ses::smtp-ports]: https://docs.aws.amazon.com/ses/latest/dg/smtp-connect.html
[aws-ses::region]: https://docs.aws.amazon.com/general/latest/gr/ses.html
[aws-ses::easy-dkim]: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-authentication-dkim-easy.html
