---
title: 'Mail Forwarding | AWS SES'
---

[Amazon SES (Simple Email Service)](https://aws.amazon.com/ses/) is intended to provide a simple way for cloud based applications to send email and receive email. For the purposes of this project only sending email via SES is supported.  Older versions of docker-mailserver used `AWS_SES_HOST` and `AWS_SES_USERPASS` to configure sending, this has changed and the setup is managed through [Configure Relay Hosts][docs-relay].

You will need to create some [Amazon SES SMTP credentials](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/smtp-credentials.html). The SMTP credentials you create will be used to populate the `RELAY_USER` and `RELAY_PASSWORD` environment variables.

The `RELAY_HOST` should match your [AWS SES region](https://docs.aws.amazon.com/general/latest/gr/ses.html), the `RELAY_PORT` will be 587.

If all of your email is being forwarded through AWS SES, `DEFAULT_RELAY_HOST` should be set accordingly.

Example:
```
DEFAULT_RELAY_HOST=[email-smtp.us-west-2.amazonaws.com]:587
```

!!! note
    If you set up [AWS Easy DKIM](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-authentication-dkim-easy.html) you can safely skip setting up DKIM as the AWS SES will take care of signing your outgoing email.

To verify proper operation, send an email to some external account of yours and inspect the mail headers. You will also see the connection to SES in the mail logs. For example:

```log
May 23 07:09:36 mail postfix/smtp[692]: Trusted TLS connection established to email-smtp.us-east-1.amazonaws.com[107.20.142.169]:25:
TLSv1.2 with cipher ECDHE-RSA-AES256-GCM-SHA384 (256/256 bits)
May 23 07:09:36 mail postfix/smtp[692]: 8C82A7E7: to=<someone@example.com>, relay=email-smtp.us-east-1.amazonaws.com[107.20.142.169]:25,
delay=0.35, delays=0/0.02/0.13/0.2, dsn=2.0.0, status=sent (250 Ok 01000154dc729264-93fdd7ea-f039-43d6-91ed-653e8547867c-000000)
```

[docs-relay]: ./relay-hosts.md
