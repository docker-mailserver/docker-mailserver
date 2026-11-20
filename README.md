# A Mail Server in a Container

[documentation::web]: https://docker-mailserver.github.io/docker-mailserver/latest/

## :page_with_curl: About

`docker-mailserver` is a production-ready fullstack but simple containerized mail server
that uses only configuration files, no SQL database. This approach makes `docker-mailserver`
easy to deploy and maintain.

**You can find [our documentation][documentation::web] on GitHub Pages!** Make sure to
select the correct version.

## :link: Links to Useful Resources

1. [An Introduction to Mail Servers](https://docker-mailserver.github.io/docker-mailserver/latest/introduction/)
2. [FAQ](https://docker-mailserver.github.io/docker-mailserver/latest/faq/)
3. [Usage](https://docker-mailserver.github.io/docker-mailserver/latest/usage/)
4. [Configuration](https://docker-mailserver.github.io/docker-mailserver/latest/config/environment/)
5. [Release Notes](./CHANGELOG.md)

## :package: Included Services

- [Postfix](http://www.postfix.org)
- [Dovecot](https://www.dovecot.org) with IMAP, SASL, POP3, LDAP, [Sieve](https://docker-mailserver.github.io/docker-mailserver/latest/config/advanced/mail-sieve) and [quotas](https://docker-mailserver.github.io/docker-mailserver/latest/config/account-management/overview/#quotas)
- [Rspamd](https://rspamd.com/)
- [Flexible certificate support](https://docker-mailserver.github.io/docker-mailserver/latest/config/environment/#ssl_type)
- [Amavis](https://www.amavis.org/)
- [SpamAssassin](http://spamassassin.apache.org/)
- [ClamAV](https://www.clamav.net/) with automatic updates
- [OpenDKIM](http://www.opendkim.org) & [OpenDMARC](https://github.com/trusteddomainproject/OpenDMARC)
- [Fail2ban](https://www.fail2ban.org/)
- [Fetchmail](http://www.fetchmail.info/fetchmail-man.html)
- [Getmail6](https://getmail6.org/documentation.html)
- [Postscreen](http://www.postfix.org/POSTSCREEN_README.html)
- [Postgrey](https://postgrey.schweikert.ch/)
- A [setup script](https://docker-mailserver.github.io/docker-mailserver/latest/config/setup.sh) for easy configuration and maintenance
