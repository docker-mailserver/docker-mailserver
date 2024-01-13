---
title: 'Best practices | MTA-STS'
hide:
  - toc # Hide Table of Contents for this page
---

MTA-STS is an optional mechanism for a domain to signal support for STARTTLS.

- It can be used to prevent man-in-the-middle-attacks from hiding STARTTLS support that would force DMS to send outbound mail through an insecure connection.
- MTA-STS is an alternative to DANE without the need of DNSSEC.
- MTA-STS is supported by some of the biggest mail providers like Google Mail and Outlook.

## Supporting MTA-STS for outbound mail

Enable this feature via the ENV setting [`ENABLE_MTA_STS=1`](../environment.md#enable_mta_sts).

!!! warning "If you have configured DANE"

    Enabling MTA-STS will by default override DANE if both are configured for a domain.

    This can be partially addressed by configuring a dane-only policy resolver before the MTA-STS entry in `smtp_tls_policy_maps`. See the [`postfix-mta-sts-resolver` documentation][postfix-mta-sts-resolver::dane] for further details.

[postfix-mta-sts-resolver::dane]: https://github.com/Snawoot/postfix-mta-sts-resolver#warning-mta-sts-policy-overrides-dane-tls-authentication

## Supporting MTA-STS for inbound mail

While this feature in DMS supports ensuring STARTTLS is used when mail is sent to another mail server, you may setup similar for mail servers sending mail to DMS.

This requires configuring your DNS and hosting the MTA-STS policy file via a webserver. A good introduction can be found on [dmarcian.com](https://dmarcian.com/mta-sts/).

