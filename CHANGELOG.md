# Changelog

## Next Major Release

- migrated the whole repository to `docker-mailserver/docker-mailserver`
- switched from TravisCI to GitHub Actions for CI/CD
- integrated stale issues action to automatically close stale issues
- adjusted issue templates
- adjusted `README.md` and split off `ENVIRONMENT.md`
- completely refactored `Dockerfile`
- adjusted `Makefile`

## v7.2.0

- Refactored `target/bin/`
- Enhanced and refactored all tests
- Added Code of Conduct
- Redesigned environment variable use
- Added missing Dovecot descriptions

## v7.1.0

- The use of default variables has changed slightly. Consult the [environment variables](./ENVIRONMENT.md) page
- New contributing guidelines were added
- Added coherent coding style and linting
- Added option to use non-default network interface
- SELinux is now supported

## 6.2.0+

- see <https://github.com/docker-mailserver/docker-mailserver/releases>

## 6.1.0

- Deliver root mail (#952)
- don't update permissions on non-existent file (#956)
- Update docker-configomat (#959)
- Support for detecting running container mount (#884)
- Report sender (#965)
  added REPORT_SENDER env variable to the container.
- Add saslauthd option for ldap_start_tls & ldap_tls_check_peer - (#979, #980)
- fix SASL domain (#892, #970)
- DOMAINNAME can fail to be set in postsrsd-wrapper.sh (#989)

## 6.0.0

- Implementation of multi-domain relay hosts (#922, #926)
  AWS_SES_HOST and AWS_SES_PORT are deprecated now.
  RELAY_HOST and RELAY_PORT are introduced to replace them.
- Password creation fix (#908, #914)
- Fixes 'duplicate log entry for /var/log/mail/mail.log' (#925, #927)
- fixed cleanup (mail_with_relays didn't get cleaned up) (#930)
- fix line breaks in postfix-summary mail error case (#936)
- Set default virus delete time (#932, #935)
  This defaults to 7 days
- Ensure that the account contains a @ (#923, #924)
- Introducing global filters. (#934)
- add missing env vars to docker-compose.yml (#937)
- set postmaster address to a sensible default (#938, #939, #940)
- Testfixes & more (#942)
