# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased](https://github.com/docker-mailserver/docker-mailserver/compare/v12.1.0...HEAD)

> **Note**: Changes and additions listed here are contained in the `:edge` image tag. These changes may not be as stable as released changes.

### Breaking

- The environment variable `ENABLE_LDAP=1` has been changed to `ACCOUNT_PROVISIONER=LDAP`.
- Postfix now defaults to supporting DSNs (_[Delivery Status Notifications](https://github.com/docker-mailserver/docker-mailserver/pull/3572#issuecomment-1751880574)_) only for authenticated users. This is a security measure to reduce spammer abuse of your DMS instance as a backscatter source.
  - If you need to modify this change, please let us know by opening an issue / discussion.
  - You can [opt-out (_enable DSNs_) via the `postfix-main.cf` override support](https://docker-mailserver.github.io/docker-mailserver/v12.1/config/advanced/override-defaults/postfix/) using the contents: `smtpd_discard_ehlo_keywords =`.
  - Likewise for authenticated users, the submission(s) ports (465 + 587) are configured internally via `master.cf` to keep DSNs enabled (_since authentication protects from abuse_).

    If necessary, DSNs for authenticated users can be disabled via the `postfix-master.cf` override with the following contents:

    ```
    submission/inet/smtpd_discard_ehlo_keywords=silent-discard,dsn
    submissions/inet/smtpd_discard_ehlo_keywords=silent-discard,dsn
    ```

### Added

- New environment variable `MARK_SPAM_AS_READ`. When set to `1`, marks incoming junk as "read" to avoid unwanted notification of junk as new mail ([#3489](https://github.com/docker-mailserver/docker-mailserver/pull/3489))

## [v12.1.0](https://github.com/docker-mailserver/docker-mailserver/releases/tag/v12.1.0)

### Added

- Rspamd:
  - note about Rspamd's web interface ([#3245](https://github.com/docker-mailserver/docker-mailserver/pull/3245))
  - add greylisting option & code refactoring ([#3206](https://github.com/docker-mailserver/docker-mailserver/pull/3206))
  - added `HFILTER_HOSTNAME_UNKNOWN` and make it configurable ([#3248](https://github.com/docker-mailserver/docker-mailserver/pull/3248))
  - add option to re-enable `reject_unknown_client_hostname` after #3248 ([#3255](https://github.com/docker-mailserver/docker-mailserver/pull/3255))
  - add DKIM helper script ([#3286](https://github.com/docker-mailserver/docker-mailserver/pull/3286))
- make `policyd-spf` configurable ([#3246](https://github.com/docker-mailserver/docker-mailserver/pull/3246))
- add 'log' command to setup for Fail2Ban ([#3299](https://github.com/docker-mailserver/docker-mailserver/pull/3299))
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
