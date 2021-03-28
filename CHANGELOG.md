# Changelog

## `v9.1.0`

This release marks the breakpoint where the wiki was transferred to a [reworked documentation](https://docker-mailserver.github.io/docker-mailserver/edge/)

- **[feat]** Introduce ENABLE_AMAVIS env ([#1866](https://github.com/docker-mailserver/docker-mailserver/pull/1866))
- **[docs]** Move wiki to gh-pages ([#1826](https://github.com/docker-mailserver/docker-mailserver/pull/1826)) - Special thanks to @polarathene 👨🏻‍💻 
  - You can [edit the docs](https://github.com/docker-mailserver/docker-mailserver/tree/master/docs/content) now directly with your code changes
  - Documentation is now versioned related to docker image versions and viewable here: https://docker-mailserver.github.io/docker-mailserver/edge/

## `v9.0.1`

A small update on the notification function which was made more stable as well as minor fixes.

- **[fix]** `_notify` cannot fail anymore - non-zero returns lead to unintended behavior in the past when `DMS_DEBUG` was not set or `0`
- **[refactor]** `check-for-changes.sh` now uses `_notify`

## `v9.0.0`

- **[feat]** Support extra `user_attributes` in accounts configuration ([#1792](https://github.com/docker-mailserver/docker-mailserver/pull/1792))
- **[feat]** Add possibility to use a custom dkim selector ([#1811](https://github.com/docker-mailserver/docker-mailserver/pull/1811))
- **[feat]** TLS: Dual (aka hybrid) certificate support! (eg ECDSA certificate with an RSA fallback for broader compatibility) ([#1801](https://github.com/docker-mailserver/docker-mailserver/pull/1801)).
  - This feature is presently only for `SSL_TYPE=manual`, all you need to do is provide your fallback certificate to the `SSL_ALT_CERT_PATH` and `SSL_ALT_KEY_PATH` ENV vars, just like your primary certificate would be setup for manual mode.
- **[security]** TLS: You can now use ECDSA certificates! ([#1802](https://github.com/docker-mailserver/docker-mailserver/pull/1802))
  - Warning: ECDSA may not be supported by legacy systems (most pre-2014). You can provide an RSA certificate as a fallback.
- **[fix]** TLS: For some docker-compose setups when restarting the docker-mailserver container, internal config state may have been persisted despite making changes that should reconfigure TLS (eg changing `SSL_TYPE` or replacing the certificate file) ([#1801](https://github.com/docker-mailserver/docker-mailserver/pull/1801)).
- **[refactor]** Split `start-mailserver.sh` ([#1820](https://github.com/docker-mailserver/docker-mailserver/pull/1820))
- **[fix]** Linting now uses local path to remove the sudo dependency ([#1831](https://github.com/docker-mailserver/docker-mailserver/pull/1831)).


### Breaking Changes:

- **[security]** TLS: `TLS_LEVEL=modern` has changed the server-side preference order to 128-bit before 256-bit encryption ([#1802](https://github.com/docker-mailserver/docker-mailserver/pull/1802)).
  - NOTE: This is still very secure but may result in misleading lower scores/grades from security audit websites.
- **[security]** TLS: `TLS_LEVEL=modern` removed support for AES-CBC cipher suites and follows best practices by supporting only AEAD cipher suites ([#1802](https://github.com/docker-mailserver/docker-mailserver/pull/1802)).
  - NOTE: As TLS 1.2 is the minimum required for modern already, AEAD cipher suites should already be supported and preferred.
- **[security]** TLS: `TLS_LEVEL=intermediate` has removed support for cipher suites using RSA for key exchange (only available with an RSA certificate) ([#1802](https://github.com/docker-mailserver/docker-mailserver/pull/1802)).
  - NOTE: This only affects Dovecot which supported 5 extra cipher suites using AES-CBC and AES-GCM. Your users MUA clients should be unaffected, preferring ECDHE or DHE for key exchange.
- **[refactor]** Complete refactoring of opendkim script ([#1812](https://github.com/docker-mailserver/docker-mailserver/pull/1812)).
  - NOTE: Use `./setup.sh config dkim help` to see the new syntax.


## `v8.0.1`

This release is a hotfix for #1781.

- **[spam]** `bl.spamcop.net` was removed from the list of spam lists since the domain expired and became unusable

## `v8.0.0`

The transfer of the old repository to the new organization has completed. This release marks the new starting point for `docker-mailserver` in the `docker-mailserver` organization. Various improvements were made, small bugs fixed and the complete CI was transferred.

- **[general]** transferred the whole repository to `docker-mailserver/docker-mailserver`
- **[general]** adjusted `README.md` and split off `ENVIRONMENT.md`
- **[ci]** usage of the GitHub Container Registry
- **[ci]** switched from TravisCI to **GitHub Actions for CI/CD**
  - now building images for `amd64` and `arm/v7` and `arm/64`
  - integrated stale issues action to automatically close stale issues
  - adjusted issue templates
- **[build]** completely refactored and improved the `Dockerfile`
- **[build]** improved the `Makefile`
- **[image improvement]** added a proper init process
- **[image improvement]** improved logging significantly
- **[image improvement]** major LDAP improvements
- **[bugfixes]** miscellaneous bug fixes and improvements

### Breaking changes of release `8.0.0`

- **[image improvement]** log-level now defaults to `warn`
- **[image improvement]** DKIM default key size now 4096
- **[general]** the `:latest` tag is now the latest release and `:edge` represents the latest push on `master`
- **[general]** URL changed from `tomav/...` to `docker-mailserver/...`

## `v7.2.0`

- **[scripts]** refactored `target/bin/`
- **[scripts]** redesigned environment variable use
- **[general]** added Code of Conduct
- **[general]** added missing Dovecot descriptions
- **[tests]** enhanced and refactored all tests

## `v7.1.0`

- **[scripts]** use of default variables has changed slightly (consult [environment variables](./ENVIRONMENT.md))
- **[scripts]** Added coherent coding style and linting
- **[scripts]** Added option to use non-default network interface
- **[general]** new contributing guidelines were added
- **[general]** SELinux is now supported
