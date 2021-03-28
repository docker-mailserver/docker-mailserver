---
title: 'Best Practices | DMARC'
hide:
  - toc # Hide Table of Contents for this page
---

!!! seealso
    DMARC Guide: https://github.com/internetstandards/toolbox-wiki/blob/master/DMARC-how-to.md

## Enabling DMARC

In `docker-mailserver`, DMARC is pre-configured out-of the box. The only thing you need to do in order to enable it, is to add new TXT entry to your DNS.

In contrast with [DKIM][docs-dkim], DMARC DNS entry does not require any keys, but merely setting the [configuration values](https://github.com/internetstandards/toolbox-wiki/blob/master/DMARC-how-to.md#overview-of-dmarc-configuration-tags). You can either handcraft the entry by yourself or use one of available generators (like https://dmarcguide.globalcyberalliance.org/).

Typically something like this should be good to start with (don't forget to replace `@domain.com` to your actual domain)
```
_dmarc.domain.com. IN TXT "v=DMARC1; p=none; rua=mailto:dmarc.report@domain.com; ruf=mailto:dmarc.report@domain.com; sp=none; ri=86400"
```

Or a bit more strict policies (mind `p=quarantine` and `sp=quarantine`):
```
_dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc.report@domain.com; ruf=mailto:dmarc.report@domain.com; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400; sp=quarantine"
```

DMARC status is not being displayed instantly in Gmail for instance. If you want to check it directly after DNS entries, you can use some services around the Internet such as https://dmarcguide.globalcyberalliance.org/ or https://ondmarc.redsift.com/. In other case, email clients will show "DMARC: PASS" in ~1 day or so.

Reference: [#1511][github-issue-1511]

[docs-dkim]: ./dkim.md
[github-issue-1511]: https://github.com/docker-mailserver/docker-mailserver/issues/1511
