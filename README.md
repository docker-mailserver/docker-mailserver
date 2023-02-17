# Docker Mailserver

[![ci::status]][ci::github] [![docker::pulls]][docker::hub] [![documentation::badge]][documentation::web]

[ci::status]: https://img.shields.io/github/actions/workflow/status/docker-mailserver/docker-mailserver/default_on_push.yml?branch=master&color=blue&label=CI&logo=github&logoColor=white&style=for-the-badge
[ci::github]: https://github.com/docker-mailserver/docker-mailserver/actions
[docker::pulls]: https://img.shields.io/docker/pulls/mailserver/docker-mailserver.svg?style=for-the-badge&logo=docker&logoColor=white
[docker::hub]: https://hub.docker.com/r/mailserver/docker-mailserver/
[documentation::badge]: https://img.shields.io/badge/DOCUMENTATION-GH%20PAGES-0078D4?style=for-the-badge&logo=git&logoColor=white
[documentation::web]: https://docker-mailserver.github.io/docker-mailserver/edge/

## :page_facing_up: About

A production-ready fullstack but simple containerized mail server (SMTP, IMAP, LDAP, Antispam, Antivirus, etc.). Only configuration files, no SQL database. Keep it simple and versioned. Easy to [deploy](#usage) and upgrade. [Documentation][documentation::web] via MkDocs. Originally created by @tomav, this project is now maintained by volunteers since January 2021.

## :boom: Issues

If you have issues, please search through [our documentation][documentation::web] **for your version** before opening an issue. The issue tracker is for issues, not for personal support. Make sure the version of the documentation matches the image version you're using!

## :link: Links to Useful Resources

1. [Documentation][documentation::web]
2. [FAQ](https://docker-mailserver.github.io/docker-mailserver/edge/faq/)
3. [Issues and Contributing](https://docker-mailserver.github.io/docker-mailserver/edge/contributing/issues-and-pull-requests/)
4. [Usage](https://docker-mailserver.github.io/docker-mailserver/edge/usage/)
5. [Examples](https://docker-mailserver.github.io/docker-mailserver/edge/examples/tutorials/basic-installation/)
6. [Release Notes](./CHANGELOG.md)
7. [Environment Variables](https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/)
8. [Updating](https://docker-mailserver.github.io/docker-mailserver/edge/faq/#updating)

## :package: Included Services

- [Postfix](http://www.postfix.org) with SMTP or LDAP authentication
- [Dovecot](https://www.dovecot.org) for SASL, IMAP or POP3, with LDAP Auth, Sieve and [quotas](https://docker-mailserver.github.io/docker-mailserver/edge/config/user-management/accounts#notes)
- [Amavis](https://www.amavis.org/)
- [SpamAssassin](http://spamassassin.apache.org/) supporting custom rules
- [ClamAV](https://www.clamav.net/) with automatic updates
- [OpenDKIM](http://www.opendkim.org)
- [OpenDMARC](https://github.com/trusteddomainproject/OpenDMARC)
- [Fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [Fetchmail](http://www.fetchmail.info/fetchmail-man.html)
- [Postscreen](http://www.postfix.org/POSTSCREEN_README.html)
- [Postgrey](https://postgrey.schweikert.ch/)
- [LetsEncrypt](https://letsencrypt.org/) and self-signed certificates
- [Setup script](https://docker-mailserver.github.io/docker-mailserver/edge/config/setup.sh) to easily configure and maintain your mail-server
- Basic [Sieve support](https://docker-mailserver.github.io/docker-mailserver/edge/config/advanced/mail-sieve) using dovecot
- SASLauthd with LDAP auth (please see the note [down below](#ldap-setup))
- Persistent data and state
- [Extension Delimiters](http://www.postfix.org/postconf.5.html#recipient_delimiter) (`you+extension@example.com` go to `you@example.com`)
