In `docker-mailserver` DMARC is configured out-of the box and the only thing you need to do is to add new TXT entry to your DNS. In contrast with [DKIM](https://github.com/tomav/docker-mailserver/wiki/Configure-DKIM), DMARC DNS entry does not require any keys but just setting the [configuration values](https://github.com/internetstandards/toolbox-wiki/blob/master/DMARC-how-to.md#overview-of-dmarc-configuration-tags). You can either handcraft the entry by yourself or use one of available generators (like https://dmarcguide.globalcyberalliance.org/).

Typically something like this should be good to start with (don't forget to replace `domain.com` to valid addresses)
`_dmarc.domain.com. IN TXT "v=DMARC1; p=none; rua=mailto:dmarc.report@domain.com; ruf=mailto:dmarc.report@domain.com; sp=none; ri=86400"`

Or a bit more strict policies (mind `p=quarantine` and `sp=quarantine`)
` _dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc.report@domain.com; ruf=dmarc.report@domain.com; fo=0; adkim=r; aspf=r; pct=100; rf=afrf; ri=86400; sp=quarantine"`

DMARC status is not being displayed in Gmail, so if you want to check it, you can use some services around the Internet such as mentioned https://dmarcguide.globalcyberalliance.org/ or https://ondmarc.redsift.com/

Reference: #1511