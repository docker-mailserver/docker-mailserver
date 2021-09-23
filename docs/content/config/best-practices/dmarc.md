---
title: 'Best Practices | DMARC'
hide:
  - toc # Hide Table of Contents for this page
---

More information at [DMARC Guide][dmarc-howto].

## Enabling DMARC

In `docker-mailserver`, DMARC is pre-configured out of the box. The only thing you need to do in order to enable it, is to add new `TXT` entry to your DNS.

In contrast with [DKIM][docs-dkim], the DMARC DNS entry does not require any keys, but merely setting the [configuration values][dmarc-howto-configtags]. You can either handcraft the entry by yourself or use one of available generators (like [this one][dmarc-tool::gca]).

Typically something like this should be good to start with (_don't forget to replace `@example.com` to your actual domain_):

```
_dmarc.example.com. IN TXT "v=DMARC1; p=none; rua=mailto:dmarc.report@example.com; ruf=mailto:dmarc.report@example.com; sp=none; ri=86400"
```

Or a bit more strict policies (_mind `p=quarantine` and `sp=quarantine`_):

```
_dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc.report@example.com; ruf=mailto:dmarc.report@example.com; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400; sp=quarantine"
```

DMARC status is not being displayed instantly in Gmail for instance. If you want to check it directly after DNS entries, you can use some services around the Internet such as from [Global Cyber Alliance][dmarc-tool::gca] or [RedSift][dmarc-tool::redsift]. In other cases, email clients will show "DMARC: PASS" in ~1 day or so.

Reference: [#1511][github-issue-1511]

[docs-dkim]: ./dkim.md
[github-issue-1511]: https://github.com/docker-mailserver/docker-mailserver/issues/1511
[dmarc-howto]: https://github.com/internetstandards/toolbox-wiki/blob/master/DMARC-how-to.md
[dmarc-howto::configtags]: https://github.com/internetstandards/toolbox-wiki/blob/master/DMARC-how-to.md#overview-of-dmarc-configuration-tags
[dmarc-tool::gca]: https://dmarcguide.globalcyberalliance.org
[dmarc-tool::redsift]: https://ondmarc.redsift.com
