# Docker Mailserver

[![ci::status]][ci::github] [![docker::pulls]][docker::hub] [![documentation::badge]][documentation::web]

[ci::status]: https://img.shields.io/github/actions/workflow/status/docker-mailserver/docker-mailserver/default_on_push.yml?branch=master&color=blue&label=CI&logo=github&logoColor=white&style=for-the-badge
[ci::github]: https://github.com/docker-mailserver/docker-mailserver/actions
[docker::pulls]: https://img.shields.io/docker/pulls/mailserver/docker-mailserver.svg?style=for-the-badge&logo=docker&logoColor=white&color=blue
[docker::hub]: https://hub.docker.com/r/mailserver/docker-mailserver/
[documentation::badge]: https://img.shields.io/badge/DOCUMENTATION-GH%20PAGES-0078D4?style=for-the-badge&logo=googledocs&logoColor=white
[documentation::web]: https://docker-mailserver.github.io/docker-mailserver/latest/

## :page_with_curl: About

A production-ready fullstack but simple containerized mail server (SMTP, IMAP, LDAP, Anti-spam, Anti-virus, etc.).
- Only configuration files, no SQL database. Keep it simple and versioned. Easy to deploy and upgrade.
- Originally created by [@tomav](https://github.com/tomav), this project is now maintained by volunteers since January 2021.

## <!-- Adds a thin line break separator style -->

> [!TIP]
> Be sure to read [our documentation][documentation::web]. It provides guidance on initial setup of your mail server.

> [!IMPORTANT]
> If you have issues, please search through [the documentation][documentation::web] **for your version** before opening an issue.
> 
> The issue tracker is for issues, not for personal support.  
> Make sure the version of the documentation matches the image version you're using!

## :link: Links to Useful Resources

1. [FAQ](https://docker-mailserver.github.io/docker-mailserver/latest/faq/)
2. [Usage](https://docker-mailserver.github.io/docker-mailserver/latest/usage/)
3. [Examples](https://docker-mailserver.github.io/docker-mailserver/latest/examples/tutorials/basic-installation/)
4. [Issues and Contributing](https://docker-mailserver.github.io/docker-mailserver/latest/contributing/issues-and-pull-requests/)
5. [Release Notes](./CHANGELOG.md)
6. [Environment Variables](https://docker-mailserver.github.io/docker-mailserver/latest/config/environment/)
7. [Updating](https://docker-mailserver.github.io/docker-mailserver/latest/faq/#how-do-i-update-dms)

## :package: Included Services

- [Postfix](http://www.postfix.org) with SMTP or LDAP authentication and support for [extension delimiters](https://docker-mailserver.github.io/docker-mailserver/latest/config/account-management/overview/#aliases)
- [Dovecot](https://www.dovecot.org) with SASL, IMAP, POP3, LDAP, [basic Sieve support](https://docker-mailserver.github.io/docker-mailserver/latest/config/advanced/mail-sieve) and [quotas](https://docker-mailserver.github.io/docker-mailserver/latest/config/account-management/overview/#quotas)
- [Rspamd](https://rspamd.com/)
- [Amavis](https://www.amavis.org/)
- [SpamAssassin](http://spamassassin.apache.org/) supporting custom rules
- [ClamAV](https://www.clamav.net/) with automatic updates
- [OpenDKIM](http://www.opendkim.org) & [OpenDMARC](https://github.com/trusteddomainproject/OpenDMARC)
- [Fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [Fetchmail](http://www.fetchmail.info/fetchmail-man.html)
- [Getmail6](https://getmail6.org/documentation.html)
- [Postscreen](http://www.postfix.org/POSTSCREEN_README.html)
- [Postgrey](https://postgrey.schweikert.ch/)
- Support for [LetsEncrypt](https://letsencrypt.org/), manual and self-signed certificates
- A [setup script](https://docker-mailserver.github.io/docker-mailserver/latest/config/setup.sh) for easy configuration and maintenance
- SASLauthd with LDAP authentication
- OAuth2 authentication (_via `XOAUTH2` or `OAUTHBEARER` SASL mechanisms_)
