# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased](https://github.com/docker-mailserver/docker-mailserver/compare/v14.0.0...HEAD)

> **Note**: Changes and additions listed here are contained in the `:edge` image tag. These changes may not be as stable as released changes.

### Breaking

- **saslauthd** mechanism support via ENV `SASLAUTHD_MECHANISMS` with `pam`, `shadow`, `mysql` values has been removed. Only `ldap` and `rimap` remain supported ([#4259](https://github.com/docker-mailserver/docker-mailserver/pull/4259))
- **getmail6** has been refactored: ([#4156](https://github.com/docker-mailserver/docker-mailserver/pull/4156))
  - The [DMS config volume](https://docker-mailserver.github.io/docker-mailserver/v15.0/config/advanced/optional-config/#volumes) now has support for `getmailrc_general.cf` for overriding [common default settings](https://docker-mailserver.github.io/docker-mailserver/v15.0/config/advanced/mail-getmail/#common-options). If you previously mounted this config file directly to `/etc/getmailrc_general` you should switch to our config volume support.
  - IMAP/POP3 example configs added to our [`config-examples`](https://github.com/docker-mailserver/docker-mailserver/tree/v15.0.0/config-examples/getmail).
  - ENV [`GETMAIL_POLL`](https://docker-mailserver.github.io/docker-mailserver/v15.0/config/environment/#getmail_poll) now supports values above 30 minutes.
  - Added `getmail` as a new service for `supervisor` to manage, replacing cron for periodic polling.
  - Generated getmail configuration files no longer set the `message_log` option. Instead of individual log files per config, the [default base settings DMS configures](https://github.com/docker-mailserver/docker-mailserver/tree/v15.0.0/target/getmail/getmailrc_general) now enables `message_log_syslog`. This aligns with how other services in DMS log to syslog where it is captured in `mail.log`.
  - Getmail configurations have changed location from the base of the DMS Config Volume, to the `getmail/` subdirectory. Any existing configurations **must be migrated manually.**
  - DMS v14 mistakenly relocated the _getmail state directory_ to the _DMS Config Volume_ as a `getmail/` subdirectory.
    - This has been corrected to `/var/lib/getmail` (_if you have mounted a DMS State Volume to `/var/mail-state`, `/var/lib/getmail` will be symlinked to `/var/mail-state/lib-getmail`_).
    - To preserve this state when upgrading to DMS v15, **you must manually migrate `getmail/` from the _DMS Config Volume_ to `lib-getmail/` in the _DMS State Volume_.**

### Security

- **Fail2ban:**
  - Ensure a secure connection, when downloading the fail2ban package ([#4080](https://github.com/docker-mailserver/docker-mailserver/pull/4080))

### Added

- **Internal:**
  - Add password confirmation to several `setup` CLI subcommands ([#4072](https://github.com/docker-mailserver/docker-mailserver/pull/4072))

### Updates

- **Fail2ban:**
  - Updated to version [`1.1.0`](https://github.com/fail2ban/fail2ban/releases/tag/1.1.0) ([#4045](https://github.com/docker-mailserver/docker-mailserver/pull/4045))
- **Documentation:**
  - Account Management and Authentication pages have been rewritten and better organized ([#4122](https://github.com/docker-mailserver/docker-mailserver/pull/4122))
  - Add a caveat for `DMS_VMAIL_UID` not being compatible with `0` / root ([#4143](https://github.com/docker-mailserver/docker-mailserver/pull/4143))
- **Postfix:**
  - By default opt-out from _Microsoft reactions_ for outbound mail ([#4120](https://github.com/docker-mailserver/docker-mailserver/pull/4120))
- Updated `jaq` version from `1.3.0` to `2.0.0` ([#4190](https://github.com/docker-mailserver/docker-mailserver/pull/4190))
- Updated Rspamd GTube settings and tests ([#4191](https://github.com/docker-mailserver/docker-mailserver/pull/4191))

### Fixes

- **Dovecot:**
  - The logwatch `ignore.conf` now also excludes Xapian messages about pending documents ([#4060](https://github.com/docker-mailserver/docker-mailserver/pull/4060))
  - `dovecot-fts-xapian` plugin was updated to `1.7.13`, fixing a regression with indexing ([#4095](https://github.com/docker-mailserver/docker-mailserver/pull/4095))
  - The "dummy account" workaround for _Dovecot Quota_ feature support no longer treats the alias as a regex when checking the Dovecot UserDB ([#4222](https://github.com/docker-mailserver/docker-mailserver/pull/4222))
- **LDAP:**
  - Correctly apply a compatibility fix for OAuth2 introduced in DMS v13.3.1 which had not been applied to the actual LDAP config changes ([#4175](https://github.com/docker-mailserver/docker-mailserver/pull/4175))
- **Internal:**
  - The main `mail.log` (_which is piped to stdout via `tail`_) now correctly begins from the first log line of the active container run. Previously some daemon logs and potential warnings/errors were omitted ([#4146](https://github.com/docker-mailserver/docker-mailserver/pull/4146))
  - Fixed a regression introduced in v14 where `postfix-main.cf` appended `stderr` output into `/etc/postfix/main.cf`, causing Postfix startup to fail ([#4147](https://github.com/docker-mailserver/docker-mailserver/pull/4147))
  - `start-mailserver.sh` removed unused `shopt -s inherit_errexit` ([#4161](https://github.com/docker-mailserver/docker-mailserver/pull/4161))
- **Rspamd:**
  - DKIM private key path checking is now performed only on paths that do not contain `$` ([#4201](https://github.com/docker-mailserver/docker-mailserver/pull/4201))
- The command `swaks --help` is now functional ([#4282](https://github.com/docker-mailserver/docker-mailserver/pull/4282))

### CI

- Removed `CONTRIBUTORS.md`, `.all-contributorsrc`, and workflow ([#4141](https://github.com/docker-mailserver/docker-mailserver/pull/4141))
- Refactored the workflows to be more secure for generating documentation previews on PRs ([#4267](https://github.com/docker-mailserver/docker-mailserver/pull/4267), [#4264](https://github.com/docker-mailserver/docker-mailserver/pull/4264), [#4262](https://github.com/docker-mailserver/docker-mailserver/pull/4262), [#4247](https://github.com/docker-mailserver/docker-mailserver/pull/4247), [#4244](https://github.com/docker-mailserver/docker-mailserver/pull/4244))

## [v14.0.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v14.0.0)

The most noteworthy change of this release is the update of the container's base image from Debian 11 ("Bullseye") to Debian 12 ("Bookworm"). This update alone involves breaking changes and requires a careful update!

### Breaking

- **Updated base image to Debian 12** ([#3403](https://github.com/docker-mailserver/docker-mailserver/pull/3403))
  - Changed the default of `DOVECOT_COMMUNITY_REPO` to `0` (disabled) - the Dovecot community repo will (for now) not be the default when building the DMS.
    - While Debian 12 (Bookworm) was released in June 2023 and the latest Dovecot `2.3.21` in Sep 2023, as of Jan 2024 there is no [Dovecot community repo available for Debian 12](https://repo.dovecot.org).
    - This results in the Dovecot version being downgraded from `2.3.21` (DMS v13.3) to `2.3.19`, which [may affect functionality when you've explicitly configured for these features](https://github.com/dovecot/core/blob/30cde20f63650d8dcc4c7ad45418986f03159946/NEWS#L1-L158):
      - OAuth2 (_mostly regarding JWT usage, or POST requests (`introspection_mode = post`) with `client_id` + `client_secret`_).
      - Lua HTTP client (_DNS related_).
  - Updated packages. For an overview, [we have a review comment on the PR that introduces Debian 12](https://github.com/docker-mailserver/docker-mailserver/pull/3403#issuecomment-1694563615)
    - Notable major version bump: `openssl 3`, `clamav 1`, `spamassassin 4`, `redis-server 7`.
    - Notable minor version bump: `postfix 3.5.23 => 3.7.9`
    - Notable minor version bump + downgrade: `dovecot 2.3.13 => 2.3.19` (_Previous release provided `2.3.21` via community repo, `2.3.19` is now the default_)
  - Updates to `packages.sh`:
    - Removed custom installations of Fail2Ban, getmail6 and Rspamd
    - Updated packages lists and added comments for maintainability
- OpenDMARC upgrade: `v1.4.0` => `v1.4.2` ([#3841](https://github.com/docker-mailserver/docker-mailserver/pull/3841))
  - Previous versions of OpenDMARC would place incoming mail from domains announcing `p=quarantaine` (_that fail the DMARC check_) into the [Postfix "hold" queue](https://www.postfix.org/QSHAPE_README.html#hold_queue) until administrative intervention.
  - [OpenDMARC v1.4.2 has disabled that feature by default](https://github.com/trusteddomainproject/OpenDMARC/issues/105), but it can be enabled again by adding the setting `HoldQuarantinedMessages true` to [`/etc/opendmarc.conf`](https://github.com/docker-mailserver/docker-mailserver/blob/v13.3.1/target/opendmarc/opendmarc.conf) (_provided from DMS_).
    - [Our `user-patches.sh` feature](https://docker-mailserver.github.io/docker-mailserver/latest/config/advanced/override-defaults/user-patches/) provides a convenient approach to updating that config file.
    - Please let us know if you disagree with the upstream default being carried with DMS, or the value of providing alternative configuration support within DMS.
- **Postfix:**
  - Postfix upgrade from 3.5 to 3.7 ([#3403](https://github.com/docker-mailserver/docker-mailserver/pull/3403))
    - `compatibility_level` was raised from `2` to `3.6`
    - Postfix has deprecated the usage of `whitelist` / `blacklist` in config parameters and logging in favor of `allowlist` / `denylist` and similar variations. ([#3403](https://github.com/docker-mailserver/docker-mailserver/pull/3403/files#r1306356328))
      - This [may affect monitoring / analysis of logs output from Postfix](https://www.postfix.org/COMPATIBILITY_README.html#respectful_logging) that expects to match patterns on the prior terminology used.
      - DMS `main.cf` has renamed `postscreen_dnsbl_whitelist_threshold` to `postscreen_dnsbl_allowlist_threshold` as part of this change.
    - `smtpd_relay_restrictions` (relay policy) is now evaluated after `smtpd_recipient_restrictions` (spam policy). Previously it was evaluated before `smtpd_recipient_restrictions`. Mail to be relayed via DMS must now pass through the spam policy first.
    - The TLS fingerprint policy has changed the default from MD5 to SHA256 (_DMS does not modify this Postfix parameter, but may affect any user customizations that do_).
- **Dovecot**
  - The "Junk" mailbox (folder) is now referenced by it's [special-use flag `\Junk`](https://docker-mailserver.github.io/docker-mailserver/v13.3/examples/use-cases/imap-folders/) instead of an explicit mailbox. ([#3925](https://github.com/docker-mailserver/docker-mailserver/pull/3925))
    - This provides compatibility for the Junk mailbox when it's folder name differs (_eg: Renamed to "Spam"_).
    - Potential breakage if your deployment modifies our `spam_to_junk.sieve` sieve script (_which is created during container startup when ENV `MOVE_SPAM_TO_JUNK=1`_) that handles storing spam mail into a users "Junk" mailbox folder.
  - **Removed support for Solr integration:** ([#4025](https://github.com/docker-mailserver/docker-mailserver/pull/4025))
    - This was a community contributed feature for FTS (Full Text Search), the docs advise using an image that has not been maintained for over 2 years and lacks ARM64 support. Based on user engagement over the years this feature has very niche value to continue to support, thus is being removed.
    - If you use Solr, support can be restored if you're willing to contribute docs for the feature that resolves the concerns raised
- **Log:**
  - The format of DMS specific logs (_from our scripts, not running services_) has been changed. The new format is `<RFC 3339 TIMESTAMP> <LOG LEVEL> <LOG EVENT SRC>: <MESSAGE>` ([#4035](https://github.com/docker-mailserver/docker-mailserver/pull/4035))
- **rsyslog:**
  - Debian 12 adjusted the `rsyslog` configuration for the default file template from `RSYSLOG_TraditionalFileFormat` to `RSYSLOG_FileFormat` (_upstream default since 2012_). This change may affect you if you have any monitoring / analysis of log output (_eg: `mail.log` / `docker logs`_).
    - The two formats are roughly equivalent to [RFC 3164](https://www.rfc-editor.org/rfc/rfc3164)) and [RFC 5424](https://datatracker.ietf.org/doc/html/rfc5424#section-1) respectively.
    - A notable difference is the change to [RFC 3339](https://www.rfc-editor.org/rfc/rfc3339.html#appendix-A) timestamps (_a strict subset of ISO 8601_). The [previous non-standardized timestamp format was defined in RFC 3164](https://www.rfc-editor.org/rfc/rfc3164.html#section-4.1.2) as `Mmm dd hh:mm:ss`.
    - To revert this change you can add `sedfile -i '1i module(load="builtin:omfile" template="RSYSLOG_TraditionalFileFormat")' /etc/rsyslog.conf` via [our `user-patches.sh` feature](https://docker-mailserver.github.io/docker-mailserver/v14.0/config/advanced/override-defaults/user-patches/).
  - Rsyslog now creates fewer log files:
    - The files `/var/log/mail/mail.{info,warn,err}` are no longer created. These files represented `/var/log/mail.log` filtered into separate priority levels. As `/var/log/mail.log` contains all mail related messages, these files (_and their rotated counterparts_) can be deleted safely.
    - `/var/log/messages`, `/var/log/debug` and several other log files not relevant to DMS were configured by default by Debian previously. These are not part of the `/var/log/mail/` volume mount, so should not impact anyone.
- **Features:**
  - The relay host feature was refactored ([#3845](https://github.com/docker-mailserver/docker-mailserver/pull/3845))
    - The only breaking change this should introduce is with the Change Detection service (`check-for-changes.sh`).
    - When credentials are configured for relays, change events that trigger the relayhost logic now reapply the relevant Postfix settings:
      - `smtp_sasl_auth_enable = yes` (_SASL auth to outbound MTA connections is enabled_)
      - `smtp_sasl_security_options = noanonymous` (_credentials are mandatory for outbound mail delivery_)
      - `smtp_tls_security_level = encrypt` (_the outbound MTA connection must always be secure due to credentials sent_)
- **Environment Variables:**
  - `SA_SPAM_SUBJECT` has been renamed into `SPAM_SUBJECT` to become anti-spam service agnostic. ([#3820](https://github.com/docker-mailserver/docker-mailserver/pull/3820))
    - As this functionality is now handled in Dovecot via a Sieve script instead of the respective anti-spam service during Postfix processing, this feature will only apply to mail stored in Dovecot. If you have relied on this feature in a different context, it will no longer be available.
    - Rspamd previously handled this functionality via the `rewrite_subject` action which as now been disabled by default in favor of the new approach with `SPAM_SUBJECT`.
    - `SA_SPAM_SUBJECT` is now deprecated and will log a warning if used. The value is copied as a fallback to `SPAM_SUBJECT`.
    - The default has changed to not prepend any prefix to the subject unless configured to do so. If you relied on the implicit prefix, you will now need to provide one explicitly.
    - `undef` was previously supported as an opt-out with `SA_SPAM_SUBJECT`. This is no longer valid, the equivalent opt-out value is now an empty value (_or rather the omission of this ENV being configured_).
    - The feature to include [`_SCORE_` tag](https://spamassassin.apache.org/full/4.0.x/doc/Mail_SpamAssassin_Conf.html#rewrite_header-subject-from-to-STRING) in your value to be replaced by the associated spam score is no longer available.
- **Supervisord:**
  - `supervisor-app.conf` renamed to `dms-services.conf` ([#3908](https://github.com/docker-mailserver/docker-mailserver/pull/3908))
- **Rspamd:**
  - The Redis history key has been changed in order to not incorporate the hostname of the container (which is desirable in Kubernetes environments) ([#3927](https://github.com/docker-mailserver/docker-mailserver/pull/3927))
- **Account Management:**
  - Addresses (accounts) are now normalized to lowercase automatically and a warning is logged in case uppercase letters are supplied ([#4033](https://github.com/docker-mailserver/docker-mailserver/pull/4033))

### Added

- **Documentation:**
  - A guide for configuring a public server to relay inbound and outbound mail from DMS on a private server ([#3973](https://github.com/docker-mailserver/docker-mailserver/pull/3973))
- **Environment Variables:**
  - `LOGROTATE_COUNT` defines the number of files kept by logrotate ([#3907](https://github.com/docker-mailserver/docker-mailserver/pull/3907))
    - The fail2ban log file is now also taken into account by `LOGROTATE_COUNT` and `LOGROTATE_INTERVAL` ([#3915](https://github.com/docker-mailserver/docker-mailserver/pull/3915), [#3919](https://github.com/docker-mailserver/docker-mailserver/pull/3919))

- **Internal:**
  - Regular container restarts are now better supported. Setup scripts that ran previously will now be skipped ([#3929](https://github.com/docker-mailserver/docker-mailserver/pull/3929))

### Updates

- **Environment Variables:**
  - `ONE_DIR` has been removed (legacy ENV) ([#3840](https://github.com/docker-mailserver/docker-mailserver/pull/3840))
    - It's only functionality remaining was to opt-out of run-time state consolidation with `ONE_DIR=0` (_when a volume was already mounted to `/var/mail-state`_).
- **Internal:**
  - Changed the Postgrey whitelist retrieved during build to  [source directly from Github](https://github.com/schweikert/postgrey/blob/master/postgrey_whitelist_clients) as the list is updated more frequently than the [author publishes at their website](https://postgrey.schweikert.ch) ([#3879](https://github.com/docker-mailserver/docker-mailserver/pull/3879))
  - Enable spamassassin only, when amavis is enabled too. ([#3943](https://github.com/docker-mailserver/docker-mailserver/pull/3943))
- **Tests:**
  - Refactored helper methods for sending e-mails with specific `Message-ID` headers and the helpers for retrieving + filtering logs, which together help isolate logs relevant to specific mail when multiple mails have been processed within a single test. ([#3786](https://github.com/docker-mailserver/docker-mailserver/pull/3786))
- **Rspamd:**
  - The `rewrite_subject` action, is now disabled by default. It has been replaced with the new `SPAM_SUBJECT` environment variable, which implements the functionality via a Sieve script instead which is anti-spam service agnostic ([#3820](https://github.com/docker-mailserver/docker-mailserver/pull/3820))
  - `RSPAMD_NEURAL` was added and is disabled by default. If switched on it will enable the experimental Rspamd "Neural network" module to add a layer of analysis to spam detection ([#3833](https://github.com/docker-mailserver/docker-mailserver/pull/3833))
  - The symbol weights of SPF, DKIM and DMARC have been adjusted again. Fixes a bug and includes more appropriate combinations of symbols ([#3913](https://github.com/docker-mailserver/docker-mailserver/pull/3913), [#3923](https://github.com/docker-mailserver/docker-mailserver/pull/3923))
- **Dovecot:**
  - `logwatch` now filters out non-error logs related to the status of the `index-worker` process for FTS indexing. ([#4012](https://github.com/docker-mailserver/docker-mailserver/pull/4012))
  - updated FTS Xapian from version 1.5.5 to 1.7.12

### Fixes

- DMS config:
  - Files that are parsed line by line are now more robust to parse by detecting and fixing line-endings ([#3819](https://github.com/docker-mailserver/docker-mailserver/pull/3819))
  - The override config `postfix-main.cf` now retains custom parameters intended for use with `postfix-master.cf` ([#3880](https://github.com/docker-mailserver/docker-mailserver/pull/3880))
- Variables related to Rspamd are declared as `readonly`, which would cause warnings in the log when being re-declared; we now guard against this issue ([#3837](https://github.com/docker-mailserver/docker-mailserver/pull/3837))
- Relay host feature refactored ([#3845](https://github.com/docker-mailserver/docker-mailserver/pull/3845))
  - `DEFAULT_RELAY_HOST` ENV can now also use the `RELAY_USER` + `RELAY_PASSWORD` ENV for supplying credentials.
  - `RELAY_HOST` ENV no longer enforces configuring outbound SMTP to require credentials. Like `DEFAULT_RELAY_HOST` it can now configure a relay where credentials are optional.
  - Restarting DMS should not be required when configuring relay hosts without these ENV, but solely via `setup relay ...`, as change detection events now apply relevant Postfix setting changes for supporting credentials too.
- Rspamd configuration: Add a missing comma in `local_networks` so that all internal IP addresses are actually considered as internal ([#3862](https://github.com/docker-mailserver/docker-mailserver/pull/3862))
- Ensure correct SELinux security context labels for files and directories moved to the mail-state volume during setup ([#3890](https://github.com/docker-mailserver/docker-mailserver/pull/3890))
- Use correct environment variable for fetchmail ([#3901](https://github.com/docker-mailserver/docker-mailserver/pull/3901))
- When using `ENABLE_GETMAIL=1` the undocumented internal location `/var/lib/getmail/` usage has been removed. Only the config volume `/tmp/docker-mailserver/getmail/` location is supported when Getmail has not been configured to deliver mail to Dovecot as advised in the DMS docs ([#4018](https://github.com/docker-mailserver/docker-mailserver/pull/4018))
- Dovecot dummy accounts (_virtual alias workaround for dovecot feature `ENABLE_QUOTAS=1`_) now correctly matches the home location of the user for that alias ([#3997](https://github.com/docker-mailserver/docker-mailserver/pull/3997))

## [v13.3.1](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v13.3.1)

### Fixes

- **Dovecot:**
  - Restrict the auth mechanisms for PassDB configs we manage (oauth2, passwd-file, ldap) ([#3812](https://github.com/docker-mailserver/docker-mailserver/pull/3812))
    - Prevents misleading auth failures from attempting to authenticate against a PassDB with incompatible auth mechanisms.
    - When the new OAuth2 feature was enabled, it introduced false-positives with logged auth failures which triggered Fail2Ban to ban the IP.
- **Rspamd:**
  - Ensure correct ownership (`_rspamd:_rspamd`) for the Rspamd DKIM directory + files `/tmp/docker-mailserver/rspamd/dkim/` ([#3813](https://github.com/docker-mailserver/docker-mailserver/pull/3813))

## [v13.3.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v13.3.0)

### Features

- **Authentication with OIDC / OAuth 2.0** 🎉
  - DMS now supports authentication via OAuth2 (_via `XOAUTH2` or `OAUTHBEARER` SASL mechanisms_) from capable services (_like Roundcube_).
    - This does not replace the need for an `ACCOUNT_PROVISIONER` (`FILE` / `LDAP`), which is required for an account to receive or send mail.
    - Successful authentication (_via Dovecot PassDB_) still requires an existing account (_lookup via Dovecot UserDB_).
- **MTA-STS** (_Optional support for mandatory outgoing TLS encryption_)
  - If enabled and the outbound recipient has an MTA-STS policy set, TLS is mandatory for delivering to that recipient.
    - Enable via the ENV `ENABLE_MTA_STS=1`
    - Supported by major email service providers like Gmail, Yahoo and Outlook.

### Added

- **Documentation:**
  - An example for how to bind outbound SMTP connections to a specific network interface ([#3465](https://github.com/docker-mailserver/docker-mailserver/pull/3465))

### Updates

- **Tests:**
  - Revised OAuth2 test ([#3795](https://github.com/docker-mailserver/docker-mailserver/pull/3795))
  - Replace `wc -l` with `grep -c` ([#3752](https://github.com/docker-mailserver/docker-mailserver/pull/3752))
  - Revised testing of service process management (supervisord) to be more robust ([#3780](https://github.com/docker-mailserver/docker-mailserver/pull/3780))
  - Refactored mail sending ([#3747](https://github.com/docker-mailserver/docker-mailserver/pull/3747) & [#3772](https://github.com/docker-mailserver/docker-mailserver/pull/3772)):
    - This change is a follow-up to [#3732](https://github.com/docker-mailserver/docker-mailserver/pull/3732) from DMS v13.2.
    - `swaks` version is now the latest from Github releases instead of the Debian package.
    - `_nc_wrapper`, `_send_mail` and related helpers expect the `.txt` filepath extension again.
    - `sending.bash` helper methods were refactored to better integrate `swaks` and accommodate different usage contexts.
    - `test/files/emails/existing/` files were removed similar to previous removal of SMTP auth files as they became redundant with `swaks`.
- **Internal:**
  - Postfix is now configured with `smtputf8_enable = no` in our default `main.cf` config (_instead of during container startup_). ([#3750](https://github.com/docker-mailserver/docker-mailserver/pull/3750))
- **Rspamd:** ([#3726](https://github.com/docker-mailserver/docker-mailserver/pull/3726)):
  - Symbol scores for SPF, DKIM & DMARC were updated to more closely align with [RFC7489](https://www.rfc-editor.org/rfc/rfc7489#page-24). Please note that complete alignment is undesirable as other symbols may be added as well, which changes the overall score calculation again, see [this issue](https://github.com/docker-mailserver/docker-mailserver/issues/3690#issuecomment-1866871996)
- **Documentation:**
  - Revised the SpamAssassin ENV docs to better communicate configuration and their relation to other ENV settings. ([#3756](https://github.com/docker-mailserver/docker-mailserver/pull/3756))
  - Detailed how mail received is assigned a spam score by Rspamd and processed accordingly ([#3773](https://github.com/docker-mailserver/docker-mailserver/pull/3773))

### Fixes

- **Setup:**
  - `setup` CLI - `setup dkim domain` now creates the keys files with the user owning the key directory ([#3783](https://github.com/docker-mailserver/docker-mailserver/pull/3783))
- **Dovecot:**
  - During container startup for Dovecot Sieve, `.sievec` source files compiled to `.svbin` now have their `mtime` adjusted post setup to ensure it is always older than the associated `.svbin` file. This avoids superfluous error logs for sieve scripts that don't actually need to be compiled again ([#3779](https://github.com/docker-mailserver/docker-mailserver/pull/3779))
- **Internal:**
  - `.gitattributes`: Always use LF line endings on checkout for files with shell script content ([#3755](https://github.com/docker-mailserver/docker-mailserver/pull/3755))
  - Fix missing 'jaq' binary for ARM architecture ([#3766](https://github.com/docker-mailserver/docker-mailserver/pull/3766))

## [v13.2.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v13.2.0)

### Security

DMS is now secured against the [recently published spoofing attack "SMTP Smuggling"](https://www.postfix.org/smtp-smuggling.html) that affected Postfix ([#3727](https://github.com/docker-mailserver/docker-mailserver/pull/3727)):

- Postfix upgraded from `3.5.18` to `3.5.23` which provides the [long-term fix with `smtpd_forbid_bare_newline = yes`](https://www.postfix.org/smtp-smuggling.html#long)
- If you are unable to upgrade to this release of DMS, you may follow [these instructions](https://github.com/docker-mailserver/docker-mailserver/issues/3719#issuecomment-1870865118) for applying the [short-term workaround](https://www.postfix.org/smtp-smuggling.html#short).
- This change should not cause compatibility concerns for legitimate mail clients, however if you use software like `netcat` to send mail to DMS (_like our test-suite previously did_) it may now be rejected (_especially with the the short-term workaround `smtpd_data_restrictions = reject_unauth_pipelining`_).
- **NOTE:** This Postfix update also includes the new parameter [`smtpd_forbid_bare_newline_exclusions`](https://www.postfix.org/postconf.5.html#smtpd_forbid_bare_newline_exclusions) which defaults to `$mynetworks` for excluding trusted mail clients excluded from the restriction.
  - With our default `PERMIT_DOCKER=none` this is not a concern.
  - Presently the Docker daemon config has `user-proxy: true` enabled by default.
    - On a host that can be reached by IPv6, this will route to a DMS IPv4 only container implicitly through the Docker network bridge gateway which rewrites the source address.
    - If your `PERMIT_DOCKER` setting allows that gateway IP, then it is part of `$mynetworks` and this attack would not be prevented from such connections.
    - If this affects your deployment, refer to [our IPv6 docs](https://docker-mailserver.github.io/docker-mailserver/v13.2/config/advanced/ipv6/) for advice on handling IPv6 correctly in Docker. Alternatively [use our `postfix-main.cf`](https://docker-mailserver.github.io/docker-mailserver/v13.2/config/advanced/override-defaults/postfix/) to set `smtpd_forbid_bare_newline_exclusions=` as empty.

### Updates

- The test suite now uses `swaks` instead of `nc`, which has multiple benefits ([#3732](https://github.com/docker-mailserver/docker-mailserver/pull/3732)):
  - `swaks` handles pipelining correctly, hence we can now use `reject_unauth_pipelining` in Postfix's configuration.
  - `swaks` provides better CLI options that make many files superflous.
  - `swaks` can also replace `openssl s_client` and handles authentication on submission ports better.
- **Postfix:**
  - We now defer rejection from unauthorized pipelining until the SMTP `DATA` command via `smtpd_data_restrictions` (_i.e. at the end of the mail transfer transaction_) ([#3744](https://github.com/docker-mailserver/docker-mailserver/pull/3744))
    - Prevously our configuration only handled this during the client and recipient restriction stages. Postfix will flag this activity when encountered, but the rejection now is handled at `DATA` where unauthorized pipelining would have been valid from this point.
    - If you had the Amavis service enabled (default), this restriction was already in place. Otherwise the concerns expressed with `smtpd_data_restrictions = reject_unauth_pipelining` from the security section above apply. We have permitted trusted clients (_`$mynetworks` or authenticated_) to bypass this restriction.

## [v13.1.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v13.1.0)

### Added

- **Dovecot:**
  - ENV `ENABLE_IMAP` ([#3703](https://github.com/docker-mailserver/docker-mailserver/pull/3703))
- **Tests:**
  - You can now use `make run-local-instance` to run a DMS image that was built locally to test changes ([#3663](https://github.com/docker-mailserver/docker-mailserver/pull/3663))
- **Internal:**
  - Log a warning when update-check is enabled, but no stable release image is used ([#3684](https://github.com/docker-mailserver/docker-mailserver/pull/3684))

### Updates

- **Documentation:**
  - Debugging - Raise awareness in the troubleshooting page for a common misconfiguration when deviating from our advice by using a bare domain ([#3680](https://github.com/docker-mailserver/docker-mailserver/pull/3680))
  - Debugging - Raise awareness of temporary downtime during certificate renewal that can cause a failure to deliver local mail ([#3718](https://github.com/docker-mailserver/docker-mailserver/pull/3718))
- **Internal:**
  - Postfix configures `virtual_mailbox_maps` and `virtual_transport` during startup instead of using defaults (configured for Dovecot) via our `main.cf` ([#3681](https://github.com/docker-mailserver/docker-mailserver/pull/3681))
- **Rspamd:**
  - Upgraded to version `3.7.5`. This was previously inconsistent between our AMD64 (`3.5`) and ARM64 (`3.4`) images ([#3686](https://github.com/docker-mailserver/docker-mailserver/pull/3686))

### Fixed

- **Internal:**
  - The container startup welcome log message now references `DMS_RELEASE` ([#3676](https://github.com/docker-mailserver/docker-mailserver/pull/3676))
  - `VERSION` was incremented for prior releases to be notified of the v13.0.1 patch release ([#3676](https://github.com/docker-mailserver/docker-mailserver/pull/3676))
  - `VERSION` is no longer included in the image ([#3711](https://github.com/docker-mailserver/docker-mailserver/pull/3711))
  - Update-check: fix 'read' exit status ([#3688](https://github.com/docker-mailserver/docker-mailserver/pull/3688))
  - `ENABLE_QUOTAS=0` no longer tries to remove non-existent config ([#3715](https://github.com/docker-mailserver/docker-mailserver/pull/3715))
  - The `postgrey` service now writes logs to the supervisor directory like all other services. Previously this was `/var/log/mail/mail.log` ([#3724](https://github.com/docker-mailserver/docker-mailserver/pull/3724))
- **Rspamd:**
  - Switch to official arm64 packages to avoid segfaults ([#3686](https://github.com/docker-mailserver/docker-mailserver/pull/3686))
- **CI / Automation:**
  - The lint workflow can now be manually triggered by maintainers ([#3714]https://github.com/docker-mailserver/docker-mailserver/pull/3714)

## [v13.0.1](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v13.0.1)

This patch release fixes two bugs that Rspamd users encountered with the `v13.0.0` release. Big thanks to the those that helped to identify these issues! ❤️

### Fixed

- **Internal:**
  - The update check service now queries the latest GH release for a version tag (_instead of from a `VERSION` file at the GH repo_). This should provide more reliable update notifications ([#3666](https://github.com/docker-mailserver/docker-mailserver/pull/3666))
- **Rspamd:**
  - The check for correct permission on the private key when signing e-mails with DKIM was flawed. The result was that a false warning was emitted ([#3669](https://github.com/docker-mailserver/docker-mailserver/pull/3669))
  - When [`RSPAMD_CHECK_AUTHENTICATED=0`][docs::env-rspamd-check-auth], DKIM signing for outbound e-mail was disabled, which is undesirable ([#3669](https://github.com/docker-mailserver/docker-mailserver/pull/3669)). **Make sure to check the documentation of [`RSPAMD_CHECK_AUTHENTICATED`][docs::env-rspamd-check-auth]**!

[docs::env-rspamd-check-auth]: https://docker-mailserver.github.io/docker-mailserver/v13.0/config/environment/#rspamd_check_authenticated

## [v13.0.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v13.0.0)

### Breaking

- **LDAP:**
  - ENV `LDAP_SERVER_HOST`, `DOVECOT_URIS`, and `SASLAUTHD_LDAP_SERVER` will now log an error if the LDAP URI scheme is missing. Previously there was an implicit fallback to `ldap://` ([#3522](https://github.com/docker-mailserver/docker-mailserver/pull/3522))
  - `ENABLE_LDAP=1` is no longer supported, please use `ACCOUNT_PROVISIONER=LDAP` ([#3507](https://github.com/docker-mailserver/docker-mailserver/pull/3507))
- **Rspamd:**
  - The deprecated path for the Rspamd custom commands file (`/tmp/docker-mailserver/rspamd-modules.conf`) now prevents successful startup. The correct path is `/tmp/docker-mailserver/rspamd/custom-commands.conf`.
- **Dovecot:**
  - Dovecot mail storage per account in `/var/mail` previously shared the same path for the accounts home directory ([#3335](https://github.com/docker-mailserver/docker-mailserver/pull/3335))
    - The home directory now is a subdirectory `home/`. This change better supports sieve scripts.
    - **NOTE:** The change has not yet been implemented for `ACCOUNT_PROVISIONER=LDAP`.
- **Postfix:**
  - `/etc/postfix/master.cf` has renamed the "smtps" service to "submissions" ([#3235](https://github.com/docker-mailserver/docker-mailserver/pull/3235))
    - This is the modern `/etc/services` name for port 465, aligning with the similar "submission" port 587.
    - If you have configured Proxy Protocol support with a reverse proxy via `postfix-master.cf` (_as [per our docs guide](https://docker-mailserver.github.io/docker-mailserver/v13.0/examples/tutorials/mailserver-behind-proxy/)_), you will want to update `smtps` to `submissions` there.
  - Postfix now defaults to supporting DSNs (_[Delivery Status Notifications](https://github.com/docker-mailserver/docker-mailserver/pull/3572#issuecomment-1751880574)_) only for authenticated users (_via ports 465 + 587_). This is a security measure to reduce spammer abuse of your DMS instance as a backscatter source. ([#3572](https://github.com/docker-mailserver/docker-mailserver/pull/3572))
    - If you need to modify this change, please let us know by opening an issue / discussion.
    - You can [opt out (_enable DSNs_) via the `postfix-main.cf` override support](https://docker-mailserver.github.io/docker-mailserver/v12.1/config/advanced/override-defaults/postfix/) using the contents: `smtpd_discard_ehlo_keywords =`.
    - Likewise for authenticated users, the submission(s) ports (465 + 587) are configured internally via `master.cf` to keep DSNs enabled (_since authentication protects from abuse_).

      If necessary, DSNs for authenticated users can be disabled via the `postfix-master.cf` override with the following contents:

      ```cf
      submission/inet/smtpd_discard_ehlo_keywords=silent-discard,dsn
      submissions/inet/smtpd_discard_ehlo_keywords=silent-discard,dsn
      ```

### Added

- **Features:**
  - `getmail` as an alternative to `fetchmail` ([#2803](https://github.com/docker-mailserver/docker-mailserver/pull/2803))
  - `setup` CLI - `setup fail2ban` gained a new `status <JAIL>` subcommand ([#3455](https://github.com/docker-mailserver/docker-mailserver/pull/3455))
- **Environment Variables:**
  - `MARK_SPAM_AS_READ`. When set to `1`, marks incoming spam as "read" to avoid unwanted "new mail" notifications for junk mail ([#3489](https://github.com/docker-mailserver/docker-mailserver/pull/3489))
  - `DMS_VMAIL_UID` and `DMS_VMAIL_GID` allow changing the default ID values (`5000:5000`) for the Dovecot vmail user and group ([#3550](https://github.com/docker-mailserver/docker-mailserver/pull/3550))
  - `RSPAMD_CHECK_AUTHENTICATED` allows authenticated users to avoid additional security checks by Rspamd ([#3440](https://github.com/docker-mailserver/docker-mailserver/pull/3440))
- **Documentation:**
  - Use-case examples / tutorials:
    - iOS mail push support ([#3513](https://github.com/docker-mailserver/docker-mailserver/pull/3513))
    - Guide for setting up Dovecot Authentication via Lua ([#3579](https://github.com/docker-mailserver/docker-mailserver/pull/3579))
    - Guide for integrating with the Crowdsec service ([#3651](https://github.com/docker-mailserver/docker-mailserver/pull/3651))
  - Debugging page:
    - New compatibility section ([#3404](https://github.com/docker-mailserver/docker-mailserver/pull/3404))
    - Now advises how to (re)start DMS correctly ([#3654](https://github.com/docker-mailserver/docker-mailserver/pull/3654))
  - Better communicate distinction between DMS FQDN and DMS mail accounts ([#3372](https://github.com/docker-mailserver/docker-mailserver/pull/3372))
  - Traefik example now includes `passthrough=true` on implicit ports ([#3568](https://github.com/docker-mailserver/docker-mailserver/pull/3568))
  - Rspamd docs have received a variety of revisions ([#3318](https://github.com/docker-mailserver/docker-mailserver/pull/3318), [#3325](https://github.com/docker-mailserver/docker-mailserver/pull/3325), [#3329](https://github.com/docker-mailserver/docker-mailserver/pull/3329))
  - IPv6 config examples with content tabs ([#3436](https://github.com/docker-mailserver/docker-mailserver/pull/3436))
  - Mention [internet.nl](https://internet.nl/test-mail/) as another testing service ([#3445](https://github.com/docker-mailserver/docker-mailserver/pull/3445))
  - `setup alias add ...` CLI help message now includes an example for aliasing to multiple recipients ([#3600](https://github.com/docker-mailserver/docker-mailserver/pull/3600))
  - `SPAMASSASSIN_SPAM_TO_INBOX=1`, now emits a debug log to raise awareness that `SA_KILL` will be ignored ([#3360](https://github.com/docker-mailserver/docker-mailserver/pull/3360))
  - `CLAMAV_MESSAGE_SIZE_LIMIT` now logs a warning when the value exceeds what ClamAV is capable of supporting (4GiB max scan size [#3332](https://github.com/docker-mailserver/docker-mailserver/pull/3332), 2GiB max file size [#3341](https://github.com/docker-mailserver/docker-mailserver/pull/3341))
  - Added note to caution against changing `mydestination` in Postfix's `main.cf` ([#3316](https://github.com/docker-mailserver/docker-mailserver/pull/3316))
- **Internal:**
  - Added a wrapper to update Postfix configuration safely ([#3484](https://github.com/docker-mailserver/docker-mailserver/pull/3484), [#3503](https://github.com/docker-mailserver/docker-mailserver/pull/3503))
  - Add debug group to `packages.sh` ([#3578](https://github.com/docker-mailserver/docker-mailserver/pull/3578))
- **Tests:**
  - Additional linting check for BASH syntax ([#3369](https://github.com/docker-mailserver/docker-mailserver/pull/3369))

### Updates

- **Misc:**
  - Changed `setup config dkim` default key size to `2048` (`open-dkim`) ([#3508](https://github.com/docker-mailserver/docker-mailserver/pull/3508))
- **Postfix:**
  - Dropped special bits from `maildrop/` and `public/` directory permissions ([#3625](https://github.com/docker-mailserver/docker-mailserver/pull/3625))
- **Rspamd:**
  - Adjusted learning of ham ([#3334](https://github.com/docker-mailserver/docker-mailserver/pull/3334))
  - Adjusted `antivirus.conf` ([#3331](https://github.com/docker-mailserver/docker-mailserver/pull/3331))
  - `logrotate` setup + Rspamd log path + tests log helper fallback path ([#3576](https://github.com/docker-mailserver/docker-mailserver/pull/3576))
  - Setup during container startup is now more resilient ([#3578](https://github.com/docker-mailserver/docker-mailserver/pull/3578))
  - Changed DKIM default config location ([#3597](https://github.com/docker-mailserver/docker-mailserver/pull/3597))
  - Removed the symlink for the `override.d/` directory in favor of using `cp`, integrated into the changedetector service, added a `--force` option for the Rspamd DKIM management, and provided a dedicated helper script for common ENV variables ([#3599](https://github.com/docker-mailserver/docker-mailserver/pull/3599))
  - Required permissions are now verified for DKIM private key files ([#3627](https://github.com/docker-mailserver/docker-mailserver/pull/3627))
- **Documentation:**
  - Documentation aligned to Compose v2 conventions, `docker-compose` command changed to `docker compose`, `docker-compose.yaml` to `compose.yaml` ([#3295](https://github.com/docker-mailserver/docker-mailserver/pull/3295))
  - Restored missing edit button ([#3338](https://github.com/docker-mailserver/docker-mailserver/pull/3338))
  - Complete rewrite of the IPv6 page ([#3244](https://github.com/docker-mailserver/docker-mailserver/pull/3244), [#3531](https://github.com/docker-mailserver/docker-mailserver/pull/3531))
  - Complete rewrite of the "Update and Cleanup" maintenance page ([#3539](https://github.com/docker-mailserver/docker-mailserver/pull/3539), [#3583](https://github.com/docker-mailserver/docker-mailserver/pull/3583))
  - Improved debugging page advice on working with logs ([#3626](https://github.com/docker-mailserver/docker-mailserver/pull/3626), [#3640](https://github.com/docker-mailserver/docker-mailserver/pull/3640))
  - Clarified the default for ENV `FETCHMAIL_PARALLEL` ([#3603](https://github.com/docker-mailserver/docker-mailserver/pull/3603))
  - Removed port 25 from FAQ entry for mail client ports supporting authenticated submission ([#3496](https://github.com/docker-mailserver/docker-mailserver/pull/3496))
  - Updated home path in docs for Dovecot Sieve ([#3370](https://github.com/docker-mailserver/docker-mailserver/pull/3370), [#3650](https://github.com/docker-mailserver/docker-mailserver/pull/3650))
  - Fixed path to `rspamd.log` ([#3585](https://github.com/docker-mailserver/docker-mailserver/pull/3585))
  - "Optional Config" page now uses consistent lowercase convention for directory names ([#3629](https://github.com/docker-mailserver/docker-mailserver/pull/3629))
  - `CONTRIBUTORS.md`: Removed redundant "All Contributors" section ([#3638](https://github.com/docker-mailserver/docker-mailserver/pull/3638))
- **Internal:**
  - LDAP config improvements (Removed implicit `ldap://` LDAP URI scheme fallback) ([#3522](https://github.com/docker-mailserver/docker-mailserver/pull/3522))
  - Changed style conventions for internal scripts ([#3361](https://github.com/docker-mailserver/docker-mailserver/pull/3361), [#3364](https://github.com/docker-mailserver/docker-mailserver/pull/3364), [#3365](https://github.com/docker-mailserver/docker-mailserver/pull/3365), [#3366](https://github.com/docker-mailserver/docker-mailserver/pull/3366), [#3368](https://github.com/docker-mailserver/docker-mailserver/pull/3368), [#3464](https://github.com/docker-mailserver/docker-mailserver/pull/3464))
- **CI / Automation:**
  - `.gitattributes` now ensures files are committed with `eol=lf` ([#3527](https://github.com/docker-mailserver/docker-mailserver/pull/3527))
  - Revised the GitHub issue bug report template ([#3317](https://github.com/docker-mailserver/docker-mailserver/pull/3317), [#3381](https://github.com/docker-mailserver/docker-mailserver/pull/3381), [#3435](https://github.com/docker-mailserver/docker-mailserver/pull/3435))
  - Clarified that the issue tracker is not for personal support ([#3498](https://github.com/docker-mailserver/docker-mailserver/pull/3498), [#3502](https://github.com/docker-mailserver/docker-mailserver/pull/3502))
  - Bumped versions of miscellaneous software (also shoutout to @dependabot) ([#3371](https://github.com/docker-mailserver/docker-mailserver/pull/3371), [#3584](https://github.com/docker-mailserver/docker-mailserver/pull/3584), [#3504](https://github.com/docker-mailserver/docker-mailserver/pull/3504), [#3516](https://github.com/docker-mailserver/docker-mailserver/pull/3516))
- **Tests:**
  - Refactored LDAP tests to current conventions ([#3483](https://github.com/docker-mailserver/docker-mailserver/pull/3483))
  - Changed OpenLDAP image to `bitnami/openldap` ([#3494](https://github.com/docker-mailserver/docker-mailserver/pull/3494))
  - Revised LDAP config + setup ([#3514](https://github.com/docker-mailserver/docker-mailserver/pull/3514))
  - Added tests for the helper function `_add_to_or_update_postfix_main()` ([#3505](https://github.com/docker-mailserver/docker-mailserver/pull/3505))
  - EditorConfig Checker lint now uses a mount path to `/check` instead of `/ci` ([#3655](https://github.com/docker-mailserver/docker-mailserver/pull/3655))

### Fixed

- **Security:**
  - Fixed issue with concatenating `$dmarc_milter` and `$dkim_milter` in `main.cf` ([#3380](https://github.com/docker-mailserver/docker-mailserver/pull/3380))
  - Fixed Rspamd DKIM signing for inbound emails ([#3439](https://github.com/docker-mailserver/docker-mailserver/pull/3439), [#3453](https://github.com/docker-mailserver/docker-mailserver/pull/3453))
  - OpenDKIM key generation is no longer broken when Rspamd is also enabled ([#3535](https://github.com/docker-mailserver/docker-mailserver/pull/3535))
- **Internal:**
  - The "database" files (_for managing users and aliases_) now correctly filters within lookup query ([#3359](https://github.com/docker-mailserver/docker-mailserver/pull/3359))
  - `_setup_spam_to_junk()` no longer registered when `SMTP_ONLY=1` ([#3385](https://github.com/docker-mailserver/docker-mailserver/pull/3385))
  - Dovecot `fts_xapian` is now compiled from source to match the Dovecot package ABI ([#3373](https://github.com/docker-mailserver/docker-mailserver/pull/3373))
- **CI:**
  - Scheduled build now have the correct permissions to run successfully ([#3345](https://github.com/docker-mailserver/docker-mailserver/pull/3345))
- **Documentation:**
  - Miscellaneous spelling and wording improvements ([#3324](https://github.com/docker-mailserver/docker-mailserver/pull/3324), [#3330](https://github.com/docker-mailserver/docker-mailserver/pull/3330), [#3337](https://github.com/docker-mailserver/docker-mailserver/pull/3337), [#3339](https://github.com/docker-mailserver/docker-mailserver/pull/3339), [#3344](https://github.com/docker-mailserver/docker-mailserver/pull/3344), [#3367](https://github.com/docker-mailserver/docker-mailserver/pull/3367), [#3411](https://github.com/docker-mailserver/docker-mailserver/pull/3411), [#3443](https://github.com/docker-mailserver/docker-mailserver/pull/3443))
- **Tests:**
  - Run `pgrep` within the actual container ([#3553](https://github.com/docker-mailserver/docker-mailserver/pull/3553))
  - `lmtp_ip.bats` improved partial failure output ([#3552](https://github.com/docker-mailserver/docker-mailserver/pull/3552))
  - Improvements to LDIF test data ([#3506](https://github.com/docker-mailserver/docker-mailserver/pull/3506))
  - Normalized for `.gitattributes` + improved `eclint` coverage ([#3566](https://github.com/docker-mailserver/docker-mailserver/pull/3566))
  - Fixed ShellCheck linting for BATS tests ([#3347](https://github.com/docker-mailserver/docker-mailserver/pull/3347))

## [v12.1.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v12.1.0)

### Added

- Rspamd:
  - note about Rspamd's web interface ([#3245](https://github.com/docker-mailserver/docker-mailserver/pull/3245))
  - add greylisting option & code refactoring ([#3206](https://github.com/docker-mailserver/docker-mailserver/pull/3206))
  - added `HFILTER_HOSTNAME_UNKNOWN` and make it configurable ([#3248](https://github.com/docker-mailserver/docker-mailserver/pull/3248))
  - add option to re-enable `reject_unknown_client_hostname` after #3248 ([#3255](https://github.com/docker-mailserver/docker-mailserver/pull/3255))
  - add DKIM helper script ([#3286](https://github.com/docker-mailserver/docker-mailserver/pull/3286))
- make `policyd-spf` configurable ([#3246](https://github.com/docker-mailserver/docker-mailserver/pull/3246))
- add 'log' command to set up for Fail2Ban ([#3299](https://github.com/docker-mailserver/docker-mailserver/pull/3299))
- `setup` command now expects accounts and aliases to be mutually exclusive ([#3270](https://github.com/docker-mailserver/docker-mailserver/pull/3270))

### Updated

- update DKIM/DMARC/SPF docs ([#3231](https://github.com/docker-mailserver/docker-mailserver/pull/3231))
- Fail2Ban:
  - made config more aggressive ([#3243](https://github.com/docker-mailserver/docker-mailserver/pull/3243) & [#3288](https://github.com/docker-mailserver/docker-mailserver/pull/3288))
  - update fail2ban config examples with current DMS default values ([#3258](https://github.com/docker-mailserver/docker-mailserver/pull/3258))
  - make Fail2Ban log persistent ([#3269](https://github.com/docker-mailserver/docker-mailserver/pull/3269))
  - update F2B docs & bind mount links ([#3293](https://github.com/docker-mailserver/docker-mailserver/pull/3293))
- Rspamd:
  - improve Rspamd docs ([#3257](https://github.com/docker-mailserver/docker-mailserver/pull/3257))
  - script stabilization ([#3261](https://github.com/docker-mailserver/docker-mailserver/pull/3261) & [#3282](https://github.com/docker-mailserver/docker-mailserver/pull/3282))
  - remove WIP warnings ([#3283](https://github.com/docker-mailserver/docker-mailserver/pull/3283))
- improve shutdown function by making PANIC_STRATEGY obsolete ([#3265](https://github.com/docker-mailserver/docker-mailserver/pull/3265))
- update `bug_report.yml` ([#3275](https://github.com/docker-mailserver/docker-mailserver/pull/3275))
- simplify `bug_report.yml` ([#3276](https://github.com/docker-mailserver/docker-mailserver/pull/3276))
- revised the contributor workflow ([#2227](https://github.com/docker-mailserver/docker-mailserver/pull/2227))

### Changed

- default registry changed from DockerHub (`docker.io`) to GHCR (`ghcr.io`) ([#3233](https://github.com/docker-mailserver/docker-mailserver/pull/3233))
- consistent namings in docs ([#3242](https://github.com/docker-mailserver/docker-mailserver/pull/3242))
- get all `policyd-spf` setup in one place ([#3263](https://github.com/docker-mailserver/docker-mailserver/pull/3263))
- miscellaneous script improvements ([#3281](https://github.com/docker-mailserver/docker-mailserver/pull/3281))
- update FAQ entries ([#3294](https://github.com/docker-mailserver/docker-mailserver/pull/3294))

### Fixed

- GitHub Actions docs update workflow ([#3241](https://github.com/docker-mailserver/docker-mailserver/pull/3241))
- fix dovecot: ldap mail delivery works ([#3252](https://github.com/docker-mailserver/docker-mailserver/pull/3252))
- shellcheck: do not check .git folder ([#3267](https://github.com/docker-mailserver/docker-mailserver/pull/3267))
- add missing -E for extended regexes in `smtpd_sender_restrictions` ([#3272](https://github.com/docker-mailserver/docker-mailserver/pull/3272))
- fix setting `SRS_EXCLUDE_DOMAINS` during startup ([#3271](https://github.com/docker-mailserver/docker-mailserver/pull/3271))
- remove superfluous `EOF` in `dmarc_dkim_spf.sh` ([#3266](https://github.com/docker-mailserver/docker-mailserver/pull/3266))
- apply fixes to helpers when using `set -eE` ([#3285](https://github.com/docker-mailserver/docker-mailserver/pull/3285))

## [12.0.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v12.0.0)

Notable changes are:

- Rspamd feature is promoted from preview status
- Services no longer use `chroot`
- Fail2Ban major version upgrade
- ARMv7 platform is no longer suppoted
- TLS 1.2 is the minimum supported protocol
- SMTP authentication on port 25 disabled
- The value of `smtpd_sender_restrictions` for Postfix has replaced the value ([#3127](https://github.com/docker-mailserver/docker-mailserver/pull/3127)):
  - In `main.cf` with `$dms_smtpd_sender_restrictions`
  - In `master.cf` inbound submissions ports 465 + 587 extend this inherited `smtpd` restriction with `$mua_sender_restrictions`

### Added

- **security**: Rspamd support:
  - integration into scripts, provisioning of configuration & documentation ([#2902](https://github.com/docker-mailserver/docker-mailserver/pull/2902),[#3016](https://github.com/docker-mailserver/docker-mailserver/pull/3016),[#3039](https://github.com/docker-mailserver/docker-mailserver/pull/3039))
  - easily adjust options & modules ([#3059](https://github.com/docker-mailserver/docker-mailserver/pull/3059))
  - advanced documentation ([#3104](https://github.com/docker-mailserver/docker-mailserver/pull/3104))
  - make disabling Redis possible ([#3132](https://github.com/docker-mailserver/docker-mailserver/pull/3132))
  - persistence for Redis ([#3143](https://github.com/docker-mailserver/docker-mailserver/pull/3143))
  - integrate into `MOVE_SPAM_TO_JUNK` ([#3159](https://github.com/docker-mailserver/docker-mailserver/pull/3159))
  - make it possible to learn from user actions ([#3159](https://github.com/docker-mailserver/docker-mailserver/pull/3159))
- heavily updated CI & tests:
  - added functionality to send mail with a helper function ([#3026](https://github.com/docker-mailserver/docker-mailserver/pull/3026),[#3103](https://github.com/docker-mailserver/docker-mailserver/pull/3103),[#3105](https://github.com/docker-mailserver/docker-mailserver/pull/3105))
  - add a dedicated page for tests with more information ([#3019](https://github.com/docker-mailserver/docker-mailserver/pull/3019))
- add information to Logwatch's mailer so `Envelope From` is properly set ([#3081](https://github.com/docker-mailserver/docker-mailserver/pull/3081))
- add vulnerability scanning workflow & security policy ([#3106](https://github.com/docker-mailserver/docker-mailserver/pull/3106))
- Add tools (ping & dig) to the image ([2989](https://github.com/docker-mailserver/docker-mailserver/pull/2989))

### Updates

- Fail2Ban major version updated to v1.0.2 ([#2959](https://github.com/docker-mailserver/docker-mailserver/pull/2959))
- heavily updated CI & tests:
  - we now run more tests in parallel bringing down overall time to build and test AMD64 to 6 minutes ([#2938](https://github.com/docker-mailserver/docker-mailserver/pull/2938),[#3038](https://github.com/docker-mailserver/docker-mailserver/pull/3038),[#3018](https://github.com/docker-mailserver/docker-mailserver/pull/3018),[#3062](https://github.com/docker-mailserver/docker-mailserver/pull/3062))
  - remove CI ENV & disable fail-fast strategy ([#3065](https://github.com/docker-mailserver/docker-mailserver/pull/3065))
  - streamlined GH Actions runners ([#3025](https://github.com/docker-mailserver/docker-mailserver/pull/3025))
  - updated BATS & helper + minor updates to BATS variables ([#2988](https://github.com/docker-mailserver/docker-mailserver/pull/2988))
  - improved consistency and documentation for test helpers ([#3012](https://github.com/docker-mailserver/docker-mailserver/pull/3012))
- improve the `clean` recipe (don't require `sudo` anymore) ([#3020](https://github.com/docker-mailserver/docker-mailserver/pull/3020))
- improve Amavis setup routine ([#3079](https://github.com/docker-mailserver/docker-mailserver/pull/3079))
- completely refactor README & parts of docs ([#3097](https://github.com/docker-mailserver/docker-mailserver/pull/3097))
- TLS setup (self-signed) error message now includes `SS_CA_CERT` ([#3168](https://github.com/docker-mailserver/docker-mailserver/pull/3168))
- Better default value for SA_KILL variable ([#3058](https://github.com/docker-mailserver/docker-mailserver/pull/3058))

### Fixed

- `restrict-access` avoid inserting duplicates ([#3067](https://github.com/docker-mailserver/docker-mailserver/pull/3067))
- correct the casing for Mime vs. MIME ([#3040](https://github.com/docker-mailserver/docker-mailserver/pull/3040))
- Dovecot:
  - Quota plugin is now properly configured via `mail_plugins` at setup ([#2958](https://github.com/docker-mailserver/docker-mailserver/pull/2958))
  - `quota-status` service (port 65265) now only binds to `127.0.0.1` ([#3057](https://github.com/docker-mailserver/docker-mailserver/pull/3057))
- OpenDMARC - Change default policy to reject ([#2933](https://github.com/docker-mailserver/docker-mailserver/pull/2933))
- Change Detection service - Use service `reload` instead of restarting process to minimize downtime ([#2947](https://github.com/docker-mailserver/docker-mailserver/pull/2947))
- Slightly faster container startup via `postconf` workaround ([#2998](https://github.com/docker-mailserver/docker-mailserver/pull/2998))
- Better group ownership to `/var/mail-state` + ClamAV in `Dockerfile` ([#3011](https://github.com/docker-mailserver/docker-mailserver/pull/3011))
- Dropping Postfix `chroot` mode:
  - Remove syslog socket created by Debian ([#3134](https://github.com/docker-mailserver/docker-mailserver/pull/3134))
  - Supervisor proxy signals for `postfix start-fg` via PID ([#3118](https://github.com/docker-mailserver/docker-mailserver/pull/3118))
- Fixed several typos ([#2990](https://github.com/docker-mailserver/docker-mailserver/pull/2990)) ([#2993](https://github.com/docker-mailserver/docker-mailserver/pull/2993))
- SRS setup fixed ([#3158](https://github.com/docker-mailserver/docker-mailserver/pull/3158))
- Postsrsd restart loop fixed ([#3160](https://github.com/docker-mailserver/docker-mailserver/pull/3160))
- Order of DKIM/DMARC milters matters ([#3082](https://github.com/docker-mailserver/docker-mailserver/pull/3082))
- Make logrotate state persistant ([#3077](https://github.com/docker-mailserver/docker-mailserver/pull/3077))

### Changed

- the Dovecot community repository is now the default ([#2901](https://github.com/docker-mailserver/docker-mailserver/pull/2901))
- moved SASL authentication socket location ([#3131](https://github.com/docker-mailserver/docker-mailserver/pull/3131))
- only add Amavis configuration to Postfix when enabled ([#3046](https://github.com/docker-mailserver/docker-mailserver/pull/3046))
- improve bug report template ([#3080](https://github.com/docker-mailserver/docker-mailserver/pull/3080))
- remove Postfix DNSBLs ([#3069](https://github.com/docker-mailserver/docker-mailserver/pull/3069))
- bigger script updates:
  - split `setup-stack.sh` ([#3115](https://github.com/docker-mailserver/docker-mailserver/pull/3115))
  - housekeeping & cleanup setup ([#3121](https://github.com/docker-mailserver/docker-mailserver/pull/3121),[#3123](https://github.com/docker-mailserver/docker-mailserver/pull/3123))
  - issue warning in case of improper restart ([#3129](https://github.com/docker-mailserver/docker-mailserver/pull/3129))
  - remove PostSRSD wrapper ([#3128](https://github.com/docker-mailserver/docker-mailserver/pull/3128))
  - miscellaneous small improvements ([#3144](https://github.com/docker-mailserver/docker-mailserver/pull/3144))
- improve Postfix config for spoof protection ([#3127](https://github.com/docker-mailserver/docker-mailserver/pull/3127))
- Change Detection service - Remove 10 sec start-up delay ([#3064](https://github.com/docker-mailserver/docker-mailserver/pull/3064))
- Postfix:
  - Stop using `chroot` + remove wrapper script ([#3033](https://github.com/docker-mailserver/docker-mailserver/pull/3033))
  - SMTP Authentication via port 25 disabled ([#3006](https://github.com/docker-mailserver/docker-mailserver/pull/3006))
- Fail2Ban - Added support packages + remove wrapper script ([#3032](https://github.com/docker-mailserver/docker-mailserver/pull/3032))
- Replace path with variable in mail_state.sh ([#3153](https://github.com/docker-mailserver/docker-mailserver/pull/3153))

### Removed

- configomat (submodule) ([#3045](https://github.com/docker-mailserver/docker-mailserver/pull/3045))
- Due to deprecation:
  - ARMv7 image support ([#2943](https://github.com/docker-mailserver/docker-mailserver/pull/2943))
  - TLS 1.2 is now the minimum supported protocol ([#2945](https://github.com/docker-mailserver/docker-mailserver/pull/2945))
  - ENV `SASL_PASSWD` ([#2946](https://github.com/docker-mailserver/docker-mailserver/pull/2946))
- Redundant:
  - Makefile `backup` target ([#3000](https://github.com/docker-mailserver/docker-mailserver/pull/3000))
  - ENV `ENABLE_POSTFIX_VIRTUAL_TRANSPORT` ([#3004](https://github.com/docker-mailserver/docker-mailserver/pull/3004))
  - `gamin` package ([#3030](https://github.com/docker-mailserver/docker-mailserver/pull/3030))

## [11.3.1](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v11.3.1)

### Fixed

- **build**:  Fix dovecot-fts-xapian dependency, when using dovecot community repository ([#2937](https://github.com/docker-mailserver/docker-mailserver/pull/2937))

## [11.3.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v11.3.0)

### Added

- **scripts**: Fail2ban - Enable network bans ([#2818](https://github.com/docker-mailserver/docker-mailserver/pull/2818))
- **ci**: run tests in parallel ([#2857](https://github.com/docker-mailserver/docker-mailserver/pull/2857))
- **docs**: added note about Docker version to documentation ([#2799](https://github.com/docker-mailserver/docker-mailserver/pull/2799))

### Changed

- **configuration**: Run fetchmail not in verbose mode ([#2859](https://github.com/docker-mailserver/docker-mailserver/pull/2859))
- **build**: cleaned up `Makefile` and its targets ([#2833](https://github.com/docker-mailserver/docker-mailserver/pull/2833))
- **configuration**: adjust handling of DNSBL return codes ([#2890](https://github.com/docker-mailserver/docker-mailserver/pull/2890))

### Updates

- **ci**: change to new output format in GH actions ([#2892](https://github.com/docker-mailserver/docker-mailserver/pull/2892))
- **build**: cleaned up Makefile ([#2833](https://github.com/docker-mailserver/docker-mailserver/pull/2833))
- **tests**: miscellaneous enhancements ([#2815](https://github.com/docker-mailserver/docker-mailserver/pull/2815))

### Fixed

- **scripts**: `./setup.sh email list` did not display aliases correctly ([#2877](https://github.com/docker-mailserver/docker-mailserver/issues/2877))
- **scripts**: Improve error handling, when parameters are missing ([#2854](https://github.com/docker-mailserver/docker-mailserver/pull/2854))
- **scripts**: Fix unbound variable error ([#2849](https://github.com/docker-mailserver/docker-mailserver/pull/2849), [#2853](https://github.com/docker-mailserver/docker-mailserver/pull/2853))
- **scripts**: Make fetchmail data persistent ([#2851](https://github.com/docker-mailserver/docker-mailserver/pull/2851))
- **scripts**: Run `user-patches.sh` right before starting daemons ([#2817](https://github.com/docker-mailserver/docker-mailserver/pull/2817))
- **scripts**: Run Amavis cron job only when Amavis is enabled ([#2831](https://github.com/docker-mailserver/docker-mailserver/pull/2831))
- **config**: `opendmarc.conf` - Change the default OpenDMARC policy to reject ([#2933](https://github.com/docker-mailserver/docker-mailserver/pull/2933))

### Deprecation Notice

- **Removing TLS 1.0 and TLS 1.1 ciphersuites from `TLS_LEVEL=intermediate`**
  You should not realistically need support for TLS 1.0 or TLS 1.1, except in niche scenarios such as an old printer/scanner device that refuses to negotiate a compatible non-vulnerable cipher. [More details covered here](https://github.com/docker-mailserver/docker-mailserver/issues/2679).
- **`SASL_PASSWD` ENV**
  An old ENV `SASL_PASSWD` has been around for supporting relay-host authentication, but since superceded by the `postfix-sasl-password.cf` config file. It will be removed in a future major release as detailed [here](https://github.com/docker-mailserver/docker-mailserver/pull/2605).
- **Platform Support - ARMv7**
  This is a very old platform, superceded by ARMv8 and newer with broad product availability around 2016 onwards.
  Support was introduced primarily for users of the older generations of Raspberry Pi. ARM64 is the modern target for ARM devices.

  If you require ARMv7 support, [please let us know](https://github.com/docker-mailserver/docker-mailserver/issues/2642).

## [11.2.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v11.2.0)

### Summary

This release features a lot of small and medium-sized changes, many related to how the image is build and tested during CI. The build now multi-stage based and requires Docker Buildkit, as the ClamAV Signatures are added via `COPY --link ...` during build-time.

### Deprecated

- The environment variable `ENABLE_LDAP` is deprecated and will be removed in [13.0.0]. Use `ACCOUNT_PROVISIONER=LDAP` now.

### Added

- **documentation**: improve cron tasks documentation and fix link in documentation
- **documentation**: added link to brakkee.org for setup of docker-mailserver on Kubernetes
- **CI**: better build caching for CI
- **CI**: improve GitHub Action CI with re-usable workflows
- **tests**: ensure excessive FD limits are avoided
- **configuration**: added `reject_unknown_client_hostname` to main.cf

### Changed

- **documentation**: update and improve K8s documentation
- **scripts**: set configomat output to loglevel debug
- **scripts**: refactor CLI commands for database management
- **scripts**: simplify Fail2Ban output
- **tests**: update submodules for BATS
- **scripts**: rework environment variables setup
- **scripts**: revised linting script
- **scripts**: `addmailuser` - remove delaying completion until `/var/mail` is ready
- **configuration**: remove unnecessary postconf switch '-e' and use single quotes where possible
- **build**: streamline COPY statements in Dockerfile
- **scripts**: improve `helpers/log.sh`
- **build**: adjust build arguments
- **build**: enhance build process

### Removed

- **configuration**: remove unnecessary configuration files

### Fixed

- **documentation**: update documentation to fix regression causing broken links
- **scripts**: `_create_accounts()` should run after waiting
- **scripts**: only calculate checksums, when there are files to monitor.
- **tests**: wait at least 30 seconds before checking the health state of the container
- **CI**: add `outputs` to `workflow_call` on `generic_build`

### Security

There are no security-related changes in this release.

---

> **Note**: This part of the changelog was created before switching to the "Keep a Changelog"-format.

## `v11.1.0`

In this release the relay-host support saw [significant internal refactoring](https://github.com/docker-mailserver/docker-mailserver/pull/2604) in preparation for a future breaking change. Similar extensive restructuring through the codebase also occurred, where [each PR provides more details](https://github.com/docker-mailserver/docker-mailserver/milestone/17?closed=1). Care was taken to avoid breakage, but there may be some risk affecting unsupported third-party customizations which our test suite is unaware of.

### Features

- There is now support for [Dovecot-Master accounts](https://docker-mailserver.github.io/docker-mailserver/v11.1/config/advanced/dovecot-master-accounts/) that provide admin access to all mail accounts ([#2535](https://github.com/docker-mailserver/docker-mailserver/pull/2535))

### Fixes

- Using Port 465 to authenticate with a relay-host no longer breaks the Amavis transport for Postfix ([#2607](https://github.com/docker-mailserver/docker-mailserver/pull/2607))
- When mounting `/var/mail-state`, disabled services will no longer copy over data redundantly ([#2608](https://github.com/docker-mailserver/docker-mailserver/pull/2608))
- Amavis is now aware of new domains detected during Change Detection, no longer skipping virus and spam filtering ([#2616](https://github.com/docker-mailserver/docker-mailserver/pull/2616))
- `setup.sh -c <container name>` no longer ignores `<container name>` when more than 1 `docker-mailserver` container is running ([#2622](https://github.com/docker-mailserver/docker-mailserver/pull/2622))

### Improvements

- The Change Detector service will now only process relevant changes ([#2615](https://github.com/docker-mailserver/docker-mailserver/pull/2615)), in addition to now monitoring `postfix-sasl-password.cf`, `postfix-relaymap.cf`, and `postfix-regexp.cf` ([#2623](https://github.com/docker-mailserver/docker-mailserver/pull/2623))
- For LDAP users that only need to support a single mail domain, `setup config dkim` should now detect the domain implicitly ([#2620](https://github.com/docker-mailserver/docker-mailserver/pull/2620))
- The container capability `SYS_PTRACE` is no longer necessary ([#2624](https://github.com/docker-mailserver/docker-mailserver/pull/2624))
- Added an example for configuring a basic container `healthcheck` command ([#2625](https://github.com/docker-mailserver/docker-mailserver/pull/2625))
- Postfix `main.cf` setting `compatibility_level` was set to `2` during our startup scripts. This is now part of our default shipped `main.cf` config ([#2597](https://github.com/docker-mailserver/docker-mailserver/pull/2597))
- The Postfix `main.cf` override/extension support via `postfix-main.cf` has been improved to support multi-line values, instead of the previous single-line only support ([#2598](https://github.com/docker-mailserver/docker-mailserver/pull/2598))

### Deprecation Notice

- **`SASL_PASSWD` ENV**
  An old ENV `SASL_PASSWD` has been around for supporting relay-host authentication, but since superceded by the `postfix-sasl-password.cf` config file. It will be removed in a future major release as detailed [here](https://github.com/docker-mailserver/docker-mailserver/pull/2605).
- **Platform Support - ARMv7**
  This is a very old platform, superceded by ARMv8 and newer with broad product availability around 2016 onwards.
  Support was introduced primarily for users the older generations of Raspberry Pi. ARM64 is the modern target for ARM devices.

  If you require ARMv7 support, [please let us know](https://github.com/docker-mailserver/docker-mailserver/issues/2642).

## `v11.0.0`

### Major Changes

1. [**Internal logging has been refactored**](https://github.com/docker-mailserver/docker-mailserver/pull/2493). The environment variable `DMS_DEBUG` has been replaced by [`LOG_LEVEL`](https://docker-mailserver.github.io/docker-mailserver/v11.0/config/environment/#log_level) to better control the verbosity of logs we output. The new logger is more structured and follows standard log conventions. `LOG_LEVEL` can be set to: `error`, `warn`, `info` (default), `debug` and `trace`.
2. [**`iptables` has been replaced by `nftables`**](https://github.com/docker-mailserver/docker-mailserver/pull/2505). The Fail2Ban configuration was adjusted accordingly. If you use `iptables` yourself (e.g. in `user-patches.sh`), make sure to update the scripts.
3. **[`PERMIT_DOCKER`](https://docker-mailserver.github.io/docker-mailserver/v11.0/config/environment/#permit_docker) has a new default value of `none`**. This change [better secures Podman](https://github.com/docker-mailserver/docker-mailserver/pull/2424); to keep the old behaviour (_adding the container IP address to Postfix's `mynetworks`_), use `PERMIT_DOCKER=container`.

### Minor Changes

1. **Many** minor improvements were made (cleanup & refactoring). Please refer to the section below to get an overview over all improvements. Moreover, there was a lot of cleanup in the scripts and in the tests. The documentation was adjusted accordingly.
2. New environment variables were added:
    1. [`CLAMAV_MESSAGE_SIZE_LIMIT`](https://docker-mailserver.github.io/docker-mailserver/v11.0/config/environment/#clamav_message_size_limit)
    2. [`TZ`](https://docker-mailserver.github.io/docker-mailserver/v11.0/config/environment/#tz)
3. SpamAssassin KAM was added with [`ENABLE_SPAMASSASSIN_KAM`](https://docker-mailserver.github.io/docker-mailserver/v11.0/config/environment/#enable_spamassassin_kam).
4. The `fail2ban` command was reworked and can now ban IP addresses as well.
5. There were a few small fixes, especially when it comes to bugs in scripts and service restart loops (no functionality changes, only fixes of existing functionality). When building an image from the Dockerfile - Installation of Postfix on modern Linux distributions should now always succeed.
6. Some default values for environment values changed: these are mostly non-critical, please refer to [#2428](https://github.com/docker-mailserver/docker-mailserver/pull/2428) and [#2487](https://github.com/docker-mailserver/docker-mailserver/pull/2487).

### Merged Pull Requests

- **[improvement]** tests: remove legacy functions / tests [#2434](https://github.com/docker-mailserver/docker-mailserver/pull/2434)
- **[improvement]** `PERMIT_DOCKER=none` as new default value [#2424](https://github.com/docker-mailserver/docker-mailserver/pull/2424)
- **[improvement]** Adjust environment variables to more sensible defaults [#2428](https://github.com/docker-mailserver/docker-mailserver/pull/2428)
- **[fix]** macOS linting support [#2448](https://github.com/docker-mailserver/docker-mailserver/pull/2448)
- **[improvement]** Rename config examples directory [#2438](https://github.com/docker-mailserver/docker-mailserver/pull/2438)
- **[docs]** FAQ - Update naked/bare domain section [#2446](https://github.com/docker-mailserver/docker-mailserver/pull/2446)
- **[improvement]** Remove obsolete `setup.sh debug inspect` command from usage description [#2454](https://github.com/docker-mailserver/docker-mailserver/pull/2454)
- **[feature]** Introduce `CLAMAV_MESSAGE_SIZE_LIMIT` env [#2453](https://github.com/docker-mailserver/docker-mailserver/pull/2453)
- **[fix]** remove SA reload for KAM [#2456](https://github.com/docker-mailserver/docker-mailserver/pull/2456)
- **[docs]** Enhance logrotate description [#2469](https://github.com/docker-mailserver/docker-mailserver/pull/2469)
- **[improvement]** Remove macOS specific code / support + shellcheck should avoid python, regardless of permissions [#2466](https://github.com/docker-mailserver/docker-mailserver/pull/2466)
- **[docs]** Update fail2ban.md [#2484](https://github.com/docker-mailserver/docker-mailserver/pull/2484)
- **[fix]** Makefile: Remove backup/restore of obsolete config directory [#2479](https://github.com/docker-mailserver/docker-mailserver/pull/2479)
- **[improvement]** scripts: small refactorings [#2485](https://github.com/docker-mailserver/docker-mailserver/pull/2485)
- **[fix]** Building on Ubuntu 21.10 failing to install postfix [#2468](https://github.com/docker-mailserver/docker-mailserver/pull/2468)
- **[improvement]** Use FQDN as `REPORT_SENDER` default value [#2487](https://github.com/docker-mailserver/docker-mailserver/pull/2487)
- **[improvement]** Improve test, get rid of sleep [#2492](https://github.com/docker-mailserver/docker-mailserver/pull/2492)
- **[feature]** scripts: new log [#2493](https://github.com/docker-mailserver/docker-mailserver/pull/2493)
- **[fix]** Restart supervisord early [#2494](https://github.com/docker-mailserver/docker-mailserver/pull/2494)
- **[improvement]** scripts: renamed function `_errex` -> `_exit_with_error` [#2497](https://github.com/docker-mailserver/docker-mailserver/pull/2497)
- **[improvement]** Remove invalid URL from SPF message [#2503](https://github.com/docker-mailserver/docker-mailserver/pull/2503)
- **[improvement]** scripts: refactored scripts located under `target/bin/` [#2500](https://github.com/docker-mailserver/docker-mailserver/pull/2500)
- **[improvement]** scripts: refactoring & miscellaneous small changes [#2499](https://github.com/docker-mailserver/docker-mailserver/pull/2499)
- **[improvement]** scripts: refactored `daemon-stack.sh` [#2496](https://github.com/docker-mailserver/docker-mailserver/pull/2496)
- **[fix]** add compatibility for Bash 4 to setup.sh [#2519](https://github.com/docker-mailserver/docker-mailserver/pull/2519)
- **[fix]** tests: disabled "quota exceeded" test [#2511](https://github.com/docker-mailserver/docker-mailserver/pull/2511)
- **[fix]** typo in setup-stack.sh [#2521](https://github.com/docker-mailserver/docker-mailserver/pull/2521)
- **[improvement]** scripts: introduce `_log` to `sedfile` [#2507](https://github.com/docker-mailserver/docker-mailserver/pull/2507)
- **[feature]** create `.github/FUNDING.yml` [#2512](https://github.com/docker-mailserver/docker-mailserver/pull/2512)
- **[improvement]** scripts: refactored `check-for-changes.sh` [#2498](https://github.com/docker-mailserver/docker-mailserver/pull/2498)
- **[improvement]** scripts: remove `DMS_DEBUG` [#2523](https://github.com/docker-mailserver/docker-mailserver/pull/2523)
- **[feature]** firewall: replace `iptables` with `nftables` [#2505](https://github.com/docker-mailserver/docker-mailserver/pull/2505)
- **[improvement]** log: adjust level and message(s) slightly for four messages [#2532](https://github.com/docker-mailserver/docker-mailserver/pull/2532)
- **[improvement]** log: introduce proper log level fallback and env getter function [#2506](https://github.com/docker-mailserver/docker-mailserver/pull/2506)
- **[feature]** scripts: added `TZ` environment variable to set timezone [#2530](https://github.com/docker-mailserver/docker-mailserver/pull/2530)
- **[improvement]** setup: added grace period for account creation [#2531](https://github.com/docker-mailserver/docker-mailserver/pull/2531)
- **[improvement]** refactor: letsencrypt implicit location discovery [#2525](https://github.com/docker-mailserver/docker-mailserver/pull/2525)
- **[improvement]** setup.sh/setup: show usage when no argument is given [#2540](https://github.com/docker-mailserver/docker-mailserver/pull/2540)
- **[improvement]** Dockerfile: Remove not needed ENVs and add comment [#2541](https://github.com/docker-mailserver/docker-mailserver/pull/2541)
- **[improvement]** chore: (setup-stack.sh) Fix a small typo [#2552](https://github.com/docker-mailserver/docker-mailserver/pull/2552)
- **[feature]** Add ban feature to fail2ban script [#2538](https://github.com/docker-mailserver/docker-mailserver/pull/2538)
- **[fix]** Fix changedetector restart loop [#2548](https://github.com/docker-mailserver/docker-mailserver/pull/2548)
- **[improvement]** chore: Drop `setup.sh` DATABASE fallback ENV [#2556](https://github.com/docker-mailserver/docker-mailserver/pull/2556)

## `v10.5.0`

### Critical Changes

1. This release fixes a critical issue for LDAP users, installing a needed package on Debian 11 on build-time. Moreover, a race-condition was eliminated ([#2341](https://github.com/docker-mailserver/docker-mailserver/pull/2341)).
2. A resource leak in `check-for-changes.sh` was fixed ([#2401](https://github.com/docker-mailserver/docker-mailserver/pull/2401))

### Other Minor Changes

1. `SPAMASSASSIN_SPAM_TO_INBOX`'s default changed to `1`. ([#2361](https://github.com/docker-mailserver/docker-mailserver/pull/2361))
2. Changedetector functionality was added to `SSL_TYPE=manual`-setups. ([#2404](https://github.com/docker-mailserver/docker-mailserver/pull/2404))
3. Four new environment variables were introduced: `LOGWATCH_SENDER`, `ENABLE_DNSBL`, `DOVECOT_INET_PROTOCOLS` and `ENABLE_SPAMASSASSIN_KAM`. ([#2362](https://github.com/docker-mailserver/docker-mailserver/pull/2362), [#2342](https://github.com/docker-mailserver/docker-mailserver/pull/2342), [#2358](https://github.com/docker-mailserver/docker-mailserver/pull/2358), [#2418](https://github.com/docker-mailserver/docker-mailserver/pull/2418))
4. There are plenty of bug fixes and documentation enhancements with this release.

### Merged Pull Requests

- **[fix]** added `libldap-common` to packages in Dockerfile in [#2341](https://github.com/docker-mailserver/docker-mailserver/pull/2341)
- **[fix]** Prevent race condition on supervisorctl reload in [#2343](https://github.com/docker-mailserver/docker-mailserver/pull/2343)
- **[docs]** Update links to dovecot docs in [#2351](https://github.com/docker-mailserver/docker-mailserver/pull/2351)
- **[fix]** tests(fix): Align with upstream `testssl` field name change in [#2353](https://github.com/docker-mailserver/docker-mailserver/pull/2353)
- **[improvement]** Make TLS tests more reliable in [#2354](https://github.com/docker-mailserver/docker-mailserver/pull/2354)
- **[feature]** Introduce ENABLE_DNSBL env in [#2342](https://github.com/docker-mailserver/docker-mailserver/pull/2342)
- **[feature]** Introduce DOVECOT_INET_PROTOCOLS env in [#2358](https://github.com/docker-mailserver/docker-mailserver/pull/2358)
- **[fix]** Fix harmless startup errors in [#2357](https://github.com/docker-mailserver/docker-mailserver/pull/2357)
- **[improvement]** Add tests for sedfile wrapper in [#2363](https://github.com/docker-mailserver/docker-mailserver/pull/2363)
- **[feature]** add env var `LOGWATCH_SENDER` in [#2362](https://github.com/docker-mailserver/docker-mailserver/pull/2362)
- **[fix]** Fixed non-number-argument in `listmailuser` in [#2382](https://github.com/docker-mailserver/docker-mailserver/pull/2382)
- **[fix]** docs: Fail2Ban - Fix links for rootless podman in [#2384](https://github.com/docker-mailserver/docker-mailserver/pull/2384)
- **[fix]** docs(kubernetes): fix image name in example in [#2385](https://github.com/docker-mailserver/docker-mailserver/pull/2385)
- **[fix]** SSL documentation contains a small bug #2381 [#2383](https://github.com/docker-mailserver/docker-mailserver/pull/2383)
- **[fix]** get rid of subshell + `exec` in `helper-functions.sh` in [#2401](https://github.com/docker-mailserver/docker-mailserver/pull/2401)
- **[docs]** Rootless Podman security update [#2393](https://github.com/docker-mailserver/docker-mailserver/pull/2393)
- **[fix]** fix: double occurrence of `/etc/postfix/regexp` in [#2397](https://github.com/docker-mailserver/docker-mailserver/pull/2397)
- **[improvement]** consistently make 1 the default value for `SPAMASSASSIN_SPAM_TO_INBOX` in [#2361](https://github.com/docker-mailserver/docker-mailserver/pull/2361)
- **[docs]** added sieve example for subaddress sorting in [#2410](https://github.com/docker-mailserver/docker-mailserver/pull/2410)
- **[feature]** Add changedetector functionality for `${SSL_TYPE} == manual` in [#2404](https://github.com/docker-mailserver/docker-mailserver/pull/2404)
- **[docs]** docs(deps): bump mkdocs-material to v8.2.1 in [#2422](https://github.com/docker-mailserver/docker-mailserver/pull/2422)
- **[feature]** Add SpamAssassin KAM in [#2418](https://github.com/docker-mailserver/docker-mailserver/pull/2418)
- **[improvement]** refactoring: split helper functions into smaller scripts in [#2420](https://github.com/docker-mailserver/docker-mailserver/pull/2420)
- **[fix]** fix: do not add accounts that already exists to account files in [#2419](https://github.com/docker-mailserver/docker-mailserver/pull/2419)

## `v10.4.0`

This release upgrades our base image from Debian 10 to Debian 11.
There is also an important regression fixed for `SSL_TYPE=letsencrypt` users.

- **[fix]** A regression with `check-for-changes.sh` introduced in `v10.3.0` affected `SSL_TYPE=letsencrypt`, preventing detection of cert renewals to restart services (_unless using `acme.json`_) [#2326](https://github.com/docker-mailserver/docker-mailserver/pull/2326)
- **[improvement]** Base image upgraded from Debian 10 Buster to Debian 11 Bullseye [#2116](https://github.com/docker-mailserver/docker-mailserver/pull/2116)
  - Postfix upgraded from `3.4` to `3.5`. Dovecot upgraded from `2.3.4` to `2.3.13`. Python 2 is no longer included in the image, Python 3 remains (_[more information](https://github.com/docker-mailserver/docker-mailserver/pull/2116#issuecomment-955615529)_).
  - `yescrypt` is now supported upstream as a password hash algorithm, `docker-mailserver` continues to use `SHA512-CRYPT` (_[more information](https://github.com/docker-mailserver/docker-mailserver/pull/2116#issuecomment-955800544)_).
- **[chore]** Dovecot statistics service disabled [#2292](https://github.com/docker-mailserver/docker-mailserver/pull/2292)

## `v10.3.0`

**WARNING:** This release had a small regression affecting the detection of changes for certificates provisioned in `/etc/letsencrypt` with the config ENV `SSL_TYPE=letsencrypt`, unless you use Traefik's `acme.json`. If you rely on this functionality to restart Postfix and Dovecot when updating your cert files, this will not work and it is advised to upgrade to `v10.4.0` or newer prior to renewal of your certificates.

- **[fix]** The Dovecot `userdb` will now additionally create "dummy" accounts for basic alias maps (_alias maps to a single real account managed by Dovecot, relaying to external providers aren't affected_) when `ENABLE_QUOTAS=1` (default) as a workaround for Postfix `quota-status` plugin querying Dovecot with inbound mail for a user, which Postfix uses to reject mail if quota has been exceeded (_to avoid risk of blacklisting from spammers abusing backscatter_) [#2248](https://github.com/docker-mailserver/docker-mailserver/pull/2248)
  - **NOTE:** If using aliases that map to another alias or multiple addresses, _this remains a risk_.
- **[fix]** `setup email list` command will no longer attempt to query Dovecot quota status when `ENABLE_QUOTAS` is disabled [#2264](https://github.com/docker-mailserver/docker-mailserver/pull/2264)
- **[fix]** `SSL_DOMAIN` ENV should now work much more reliably [#2274](https://github.com/docker-mailserver/docker-mailserver/pull/2274), [#2278](https://github.com/docker-mailserver/docker-mailserver/pull/2278), [#2279](https://github.com/docker-mailserver/docker-mailserver/pull/2279)
- **[fix]** DKIM - Removed `refile:` (_regex type_) from KeyTable entry in `opendkim.conf`, fixes validation error output from `opendkim-testkey` [#2249](https://github.com/docker-mailserver/docker-mailserver/pull/2249)
- **[fix]** DMARC - Removed quotes around the hostname value in `opendmarc.conf`. This avoids an authentication failure where an OpenDKIM header was previously ignored [#2291](https://github.com/docker-mailserver/docker-mailserver/pull/2291)
- **[fix]** When using `ONE_DIR=1` (default), the `spool-postfix` folder now has the correct permissions carried over. This resolves some failures notably with sieve filters [#2273](https://github.com/docker-mailserver/docker-mailserver/pull/2273)
- **[improvement]** Warnings are now logged for ClamAV and SpamAssassin if they are enabled but Amavis is disabled (_which is required for them to work correctly_) [#2251](https://github.com/docker-mailserver/docker-mailserver/pull/2251)
- **[improvement]** `user-patches.sh` is now invoked via `bash` to assist Kubernetes deployments with `ConfigMap` [#2295](https://github.com/docker-mailserver/docker-mailserver/pull/2295)

### Internal

These changes are primarily internal and are only likely relevant to users that maintain their own modifications related to the changed files.

- **[chore]** Redundant config from Postfix `master.cf` has been removed, it should not affect any users as our images have not included any of the related processes [#2272](https://github.com/docker-mailserver/docker-mailserver/pull/2272)
- **[refactor]** `check-for-changes.sh` was carrying some duplicate code from `setup-stack.sh` that was falling out of sync, they now share common code [#2260](https://github.com/docker-mailserver/docker-mailserver/pull/2260)
- **[refactor]** `acme.json` extraction was refactored into a CLI utility and updated to Python 3 (_required for future upgrade to Debian 11 Bullseye base image_) [#2274](https://github.com/docker-mailserver/docker-mailserver/pull/2274)
- **[refactor]** As part of the Traefik `acme.json` and `SSL_DOMAIN` work, logic for `SSL_TYPE=letsencrypt` was also revised [#2278](https://github.com/docker-mailserver/docker-mailserver/pull/2278)
- **[improvement]** Some minor tweaks to how we derive the internal `HOSTNAME` and `DOMAINNAME` from user configured `hostname` and `domainname` settings [#2280](https://github.com/docker-mailserver/docker-mailserver/pull/2280)

## `v10.2.0`

- You no longer need to maintain a copy of `setup.sh` matching your version release from v10.2 of `docker-mailserver` onwards. Version specific functionality of `setup.sh` has moved into the container itself, while `setup.sh` remains as a convenient wrapper to: `docker exec -it <container name> setup <command>`.
- [`ONE_DIR`](https://docker-mailserver.github.io/docker-mailserver/v10.2/config/environment/#one_dir) now defaults to enabled (`1`).
- For anyone relying on internal location of certificates (_internal copy of mounted files at startup_), the Postfix and Dovecot location of `/etc/postfix/ssl` has changed to `/etc/dms/tls`. This may affect any third-party `user-patches.sh` scripts that depended on this path to update certs.
- The [_Let's Encrypt_ section of our SSL / TLS docs](https://docker-mailserver.github.io/docker-mailserver/v10.2/config/security/ssl#lets-encrypt-recommended) has been brought up to date.

### Bigger scripts-related improvements

- **[scripts]** update `setup.sh` to now use a running container first if one exists [#2134](https://github.com/docker-mailserver/docker-mailserver/pull/2134)
- **[scripts]** included `setup.sh` functionality inside the container to be version independent again [#2174](https://github.com/docker-mailserver/docker-mailserver/pull/2174)
- **[scripts]** `HOSTNAME` and `DOMAINNAME` setup improved [#2175](https://github.com/docker-mailserver/docker-mailserver/pull/2175)
- **[scripts]** `delmailuser` can now delete mailboxed without TLD [#2172](https://github.com/docker-mailserver/docker-mailserver/pull/2172)
- **[scripts]** properly exit on failure ([#2199](https://github.com/docker-mailserver/docker-mailserver/pull/2199) in conjunction with [#2196](https://github.com/docker-mailserver/docker-mailserver/pull/2196))
- **[scripts]** make `setup.sh` completely non-interactive for Podman users [#2201](https://github.com/docker-mailserver/docker-mailserver/pull/2201)

### Security

Some internal refactoring and fixes happened this release cycle in [#2196](https://github.com/docker-mailserver/docker-mailserver/pull/2196):

- **[improve]** The Postfix and Dovecot location of `/etc/postfix/ssl` has changed to `/etc/dms/tls`
- **[improve]** An invalid `SSL_TYPE` or a valid value with an invalid configuration will now panic, exiting the container and emitting a fatal error to the logs
- **[fix]** An unconfigured/empty `SSL_TYPE` ENV now correctly disables SSL support for Dovecot and general Postfix configurations. A reminder that this is unsupported officially, and is only intended for tests and troubleshooting. Use only [a valid `SSL_TYPE`](https://docker-mailserver.github.io/docker-mailserver/v10.2/config/environment/#ssl_type) (_`letsencrypt` and `manual` are recommended_) for production deployments
- **[fix]** `TLS_LEVEL=intermediate` now modifies the system (container) `openssl.cnf` config to set the minimum protocol to TLS 1.0 (_from 1.2_) and cipher-suite support to `DEFAULT@SECLEVEL=1` (_from `2`_). This change is required for Dovecot in upcoming Debian Bullseye upgrade, to be compatible with the `TLS_LEVEL=intermediate` cipher-suite profile. It may affect other software within the container that relies on this openssl config, should you extend the Docker image [#2193](https://github.com/docker-mailserver/docker-mailserver/pull/2193)
- **[fix]** Provide DH parameters (_default: RFC 7919 group `ffdhe406.pem`_) at build-time, instead of during startup. Custom DH parameters regardless of `ONE_DIR` are now only detected when mounted to `/tmp/docker-mailserver/dhparams.pem` [#2192](https://github.com/docker-mailserver/docker-mailserver/pull/2192)
- **[docs]** Revise the _Let's Encrypt_ section of our SSL / TLS docs [#2209](https://github.com/docker-mailserver/docker-mailserver/pull/2209)

### Miscellaneous small additions and changes

- **[ci]** improved caching [#2197](https://github.com/docker-mailserver/docker-mailserver/pull/2197)
- **[ci]** refactored spam tests and introduced common container setup template [#2198](https://github.com/docker-mailserver/docker-mailserver/pull/2198)
- **[fix]** update Fail2Ban wrapper to propagate errors to user [#2170](https://github.com/docker-mailserver/docker-mailserver/pull/2170)
- **[fix]** Dockerfile `sed`'s are now checked [#2158](https://github.com/docker-mailserver/docker-mailserver/pull/2158)
- **[general]** Updated default value of `ONE_DIR` to `1` [#2148](https://github.com/docker-mailserver/docker-mailserver/pull/2148)
- **[docs]** updated Kubernetes documentation [#2111](https://github.com/docker-mailserver/docker-mailserver/pull/2111)
- **[docs]** introduced dedicated Podman documentation [#2179](https://github.com/docker-mailserver/docker-mailserver/pull/2179)
- **[docs]** miscellaneous documentation improvements
- **[misc]** introduced GitHub issue forms for issue templates [#2160](https://github.com/docker-mailserver/docker-mailserver/pull/2160)
- **[misc]** Removed the internal `mkcert.sh` script for Dovecot as it is no longer needed [#2196](https://github.com/docker-mailserver/docker-mailserver/pull/2196)

## `v10.1.2`

This is bug fix release. It reverts [a regression](https://github.com/docker-mailserver/docker-mailserver/issues/2154) introduced with [#2104](https://github.com/docker-mailserver/docker-mailserver/pull/2104).

## `v10.1.1`

This release mainly improves on `v10.1.0` with small bugfixes/improvements and dependency updates

- **[feat]** Add logwatch maillog.conf file to support /var/log/mail/ ([#2112](https://github.com/docker-mailserver/docker-mailserver/pull/2112))
- **[docs]** `CONTRIBUTORS.md` now also shows every code contributor from the past ([#2143](https://github.com/docker-mailserver/docker-mailserver/pull/2143))
- **[improve]** Avoid chmod +x when not needed ([#2127](https://github.com/docker-mailserver/docker-mailserver/pull/2127))
- **[improve]** check-for-changes: performance improvements ([#2104](https://github.com/docker-mailserver/docker-mailserver/pull/2104))
- **[dependency]** Update various dependencies through docs and base image
- **[security]** This release contains also [security fixes for OpenSSL](https://www.openssl.org/news/secadv/20210824.txt)

## `v10.1.0`

This release mainly improves on `v10.0.0` with many bugfixes.

- **[docs]** Various documentation updates ([#2105](https://github.com/docker-mailserver/docker-mailserver/pull/2105), [#2045](https://github.com/docker-mailserver/docker-mailserver/pull/2045), [#2043](https://github.com/docker-mailserver/docker-mailserver/pull/2043), [#2035](https://github.com/docker-mailserver/docker-mailserver/pull/2035), [#2001](https://github.com/docker-mailserver/docker-mailserver/pull/2001))
- **[misc]** Fixed a lot of small bugs, updated dependencies and improved functionality ([#2095](https://github.com/docker-mailserver/docker-mailserver/pull/2095), [#2047](https://github.com/docker-mailserver/docker-mailserver/pull/2047), [#2046](https://github.com/docker-mailserver/docker-mailserver/pull/2046), [#2041](https://github.com/docker-mailserver/docker-mailserver/pull/2041), [#1980](https://github.com/docker-mailserver/docker-mailserver/pull/1980), [#2030](https://github.com/docker-mailserver/docker-mailserver/pull/2030), [#2024](https://github.com/docker-mailserver/docker-mailserver/pull/2024), [#2001](https://github.com/docker-mailserver/docker-mailserver/pull/2001), [#2000](https://github.com/docker-mailserver/docker-mailserver/pull/2000), [#2059](https://github.com/docker-mailserver/docker-mailserver/pull/2059))
- **[feat]** Added dovecot-fts-xapian ([#2064](https://github.com/docker-mailserver/docker-mailserver/pull/2064))
- **[security]** Switch GPG keyserver ([#2051](https://github.com/docker-mailserver/docker-mailserver/pull/2051))

## `v10.0.0`

This release improves on `9.1.0` in many aspect, including general fixes, Fail2Ban, LDAP and documentation. This release contains breaking changes.

- **[general]** Fixed many prose errors (spelling, grammar, indentation).
- **[general]** Documentation is better integrated into the development process and it's visibility within the project increased ([#1878](https://github.com/docker-mailserver/docker-mailserver/pull/1878)).
- **[general]** Added `stop_grace_period:` to example Compose file and supervisord ([#1896](https://github.com/docker-mailserver/docker-mailserver/pull/1896) [#1945](https://github.com/docker-mailserver/docker-mailserver/pull/1945))
- **[general]** `./setup.sh email list` was enhanced, now showing information neatly ([#1898](https://github.com/docker-mailserver/docker-mailserver/pull/1898))
- **[general]** Added update check and notification ([#1976](https://github.com/docker-mailserver/docker-mailserver/pull/1976), [#1951](https://github.com/docker-mailserver/docker-mailserver/pull/1951))
- **[general]** Moved environment variables to the documentation and improvements ([#1948](https://github.com/docker-mailserver/docker-mailserver/pull/1948), [#1947](https://github.com/docker-mailserver/docker-mailserver/pull/1947), [#1931](https://github.com/docker-mailserver/docker-mailserver/pull/1931))
- **[security]** Major Fail2Ban improvements (cleanup, update and breaking changes, see below)
- **[fix]** `./setup.sh email del ...` now works properly
- **[code]** Added color variables to `setup.sh` and improved the script as a whole ([#1879](https://github.com/docker-mailserver/docker-mailserver/pull/1879), [#1886](https://github.com/docker-mailserver/docker-mailserver/pull/1886))
- **[ldap]** Added `LDAP_QUERY_FILTER_SENDERS` ([#1902](https://github.com/docker-mailserver/docker-mailserver/pull/1902))
- **[ldap]** Use dovecots LDAP `uris` connect option instead of `hosts` ([#1901](https://github.com/docker-mailserver/docker-mailserver/pull/1901))
- **[ldap]** Complete rework of LDAP documentation ([#1921](https://github.com/docker-mailserver/docker-mailserver/pull/1921))
- **[docs]** PRs that contain changes to docs will now be commented with a preview link ([#1988](https://github.com/docker-mailserver/docker-mailserver/pull/1988))

### Breaking Changes

- **[security]** Fail2Ban adjustments:
  - Fail2ban v0.11.2 is now used ([#1965](https://github.com/docker-mailserver/docker-mailserver/pull/1965)).
  - The previous F2B config (from an old Debian release) has been replaced with the latest default config for F2B shipped by Debian 10.
  - The new default blocktype is now `DROP`, not `REJECT` ([#1914](https://github.com/docker-mailserver/docker-mailserver/pull/1914)).
  - A ban now applies to all ports (`iptables-allports`), not just the ones that were "attacked" ([#1914](https://github.com/docker-mailserver/docker-mailserver/pull/1914)).
  - Fail2ban 0.11 is totally compatible to 0.10, but the database got some new tables and fields (auto-converted during the first start), so once updated to DMS 10.0.0, you have to remove the database `mailstate:/lib-fail2ban/fail2ban.sqlite3` if you would need to downgrade to DMS 9.1.0 for some reason.
- **[ldap]** Removed `SASLAUTHD_LDAP_SSL`. Instead provide a protocol in `SASLAUTHD_LDAP_SERVER` and adjust `SASLAUTHD_LDAP_` default values ([#1989](https://github.com/docker-mailserver/docker-mailserver/pull/1989)).
- **[general]** Removed `stable` release tag ([#1975](https://github.com/docker-mailserver/docker-mailserver/pull/1975)):
  - Scheduled builds are now based off `edge`.
  - Instead of `stable`, please use the latest version tag available (_or the `latest` tag_).
  - The `stable` image tag will be removed from DockerHub in the near future.
- **[setup]** Removed `./setup config ssl` command (_deprecated since v9_). `SSL_TYPE=self-signed` remains supported however. ([`dc8f49de`](https://github.com/docker-mailserver/docker-mailserver/commit/dc8f49de548e2c2e2aa321841585153a99cd3858), [#2021](https://github.com/docker-mailserver/docker-mailserver/pull/2021))

## `v9.1.0`

This release marks the breakpoint where the wiki was transferred to a [reworked documentation](https://docker-mailserver.github.io/docker-mailserver/latest/)

- **[feat]** Introduce ENABLE_AMAVIS env ([#1866](https://github.com/docker-mailserver/docker-mailserver/pull/1866))
- **[docs]** Move wiki to gh-pages ([#1826](https://github.com/docker-mailserver/docker-mailserver/pull/1826)) - Special thanks to @polarathene 👨🏻‍💻
  - You can [edit the docs](https://github.com/docker-mailserver/docker-mailserver/tree/master/docs/content) now directly with your code changes
  - Documentation is now versioned related to docker image versions and viewable here: <https://docker-mailserver.github.io/docker-mailserver/latest/>

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

### Breaking Changes

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
