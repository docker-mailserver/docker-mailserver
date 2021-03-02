---
title: 'Mail Forwarding | AWS SES'
---

!!! warning
    New configuration, see [Configure Relay Hosts][docs-relay]

Instead of letting postfix deliver mail directly it is possible to configure it to deliver outgoing email via Amazon SES (Simple Email Service). (Receiving inbound email via SES is not implemented.) The configuration follows the guidelines provided by AWS in https://docs.aws.amazon.com/ses/latest/DeveloperGuide/postfix.html, specifically, the `STARTTLS` method.

As described in the AWS Developer Guide you will have to generate SMTP credentials and define the following two environment variables in the docker-compose.yml with the appropriate values for your AWS SES subscription (the values for `AWS_SES_USERPASS` are the "SMTP username" and "SMTP password" provided when you create SMTP credentials for SES):

```yaml
environment:
  - AWS_SES_HOST=email-smtp.us-east-1.amazonaws.com
  - AWS_SES_USERPASS=AKIAXXXXXXXXXXXXXXXX:kqXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

If necessary, you can also provide `AWS_SES_PORT`. If not provided, it defaults to 25.

When you start the container you will see a log line as follows confirming the configuration:

```log
Setting up outgoing email via AWS SES host email-smtp.us-east-1.amazonaws.com
```

To verify proper operation, send an email to some external account of yours and inspect the mail headers. You will also see the connection to SES in the mail logs. For example:

```log
May 23 07:09:36 mail postfix/smtp[692]: Trusted TLS connection established to email-smtp.us-east-1.amazonaws.com[107.20.142.169]:25:
TLSv1.2 with cipher ECDHE-RSA-AES256-GCM-SHA384 (256/256 bits)
May 23 07:09:36 mail postfix/smtp[692]: 8C82A7E7: to=<someone@example.com>, relay=email-smtp.us-east-1.amazonaws.com[107.20.142.169]:25,
delay=0.35, delays=0/0.02/0.13/0.2, dsn=2.0.0, status=sent (250 Ok 01000154dc729264-93fdd7ea-f039-43d6-91ed-653e8547867c-000000)
```

[docs-relay]: ./relay-hosts.md
