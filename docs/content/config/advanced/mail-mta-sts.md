---
title: 'Advanced | MTA-STS'
---

MTA-STS is an optional mechanism for a domain to signal support for
STARTTLS. It can be used to prevent man-in-the-middle-attacks hiding the
feature to force mail servers to send outgoing emails as plain text.
MTA-STS is an alternative to DANE without the need of DNSSEC.

MTA-STS is supported by some of the biggest mail providers like Google Mail
and Outlook.

## Supporting MTA-STS for outgoing mails

This is enabled by setting `ENABLE_MTA_STS=1` [](../environment.md#enable_mta_sts)
in the environment.

!!! warning

    MTA-STS will by default override DANE if both are in used by a domain.
    This can be partially addressed by configuring a dane-only policy resolver
    before the MTA-STS entry in smtp_tls_policy_maps. See [the postfix-mta-sts-resolver documentation](https://github.com/Snawoot/postfix-mta-sts-resolver#warning-mta-sts-policy-overrides-dane-tls-authentication)
    for further details.

## Supporting MTA-STS for incoming mails

A good introduction can be found on [dmarcian.com](https://dmarcian.com/mta-sts/).
