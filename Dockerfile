# syntax=docker.io/docker/dockerfile:1

# This Dockerfile provides three stages:
# - stage-base:  installs all packages and third-party software (`build.sh`)
# - stage-main:  adjusts the installed software for DMS and adds `rootfs/`
# - stage-final: sets the runtime configuration (ENV, EXPOSE, ENTRYPOINT, CMD) and the image labels
#
# Only instructions of the OCI image specification are used (no `SHELL`, no `HEALTHCHECK`), so every OCI
# compliant builder (Docker, Podman, Buildah, ...) builds the image without warnings. Without `SHELL`,
# `RUN` uses `/bin/sh`: heredocs start with `set -e`, and everything that needs Bash lives in a script.

ARG DEBIAN_FRONTEND=noninteractive
ARG DOVECOT_COMMUNITY_REPO=0
ARG LOG_LEVEL=trace

#
# base stage installs all packages
#

FROM docker.io/debian:13-slim AS stage-base

ARG DEBIAN_FRONTEND
ARG DOVECOT_COMMUNITY_REPO
ARG LOG_LEVEL

# -----------------------------------------------
# --- Packages ----------------------------------
# -----------------------------------------------

COPY --chmod=+x rootfs/usr/local/bin/sedfile /usr/local/bin/sedfile
COPY build.sh /build/
COPY rootfs/usr/local/lib/dms/helpers/log.sh /usr/local/lib/dms/helpers/log.sh

RUN /bin/bash /build/build.sh && rm -r /build

#
# main stage adjusts the installed software for DMS and adds config and scripts
#

FROM stage-base AS stage-main

# -----------------------------------------------
# --- ClamAV & FreshClam ------------------------
# -----------------------------------------------

# Copy over latest DB updates from official ClamAV image. This is better than running `freshclam`,
# which would require an extra memory of 500MB+ during an image build.
# When using `COPY --link`, the `--chown` option is only compatible with numeric ID values.
# hadolint ignore=DL3021
COPY --link --chown=200 --from=docker.io/clamav/clamav-debian:latest /var/lib/clamav /var/lib/clamav

RUN <<EOF
  set -e
  # `COPY --link --chown=200` has a bug when built by the buildx docker-container driver.
  # Restore ownership of parent dirs (Bug: https://github.com/moby/buildkit/issues/3912)
  chown root:root /var /var/lib

  chmod 644 /etc/clamav/freshclam.conf
  sedfile -i 's/Foreground false/Foreground true/g' /etc/clamav/clamd.conf
  mkdir /var/run/clamav
  chown -R clamav:root /var/run/clamav
  rm -rf /var/log/clamav/
EOF

# -----------------------------------------------
# --- Package Configuration ---------------------
# -----------------------------------------------

# DL4006: the only pipe is `echo | crontab`, `echo` cannot fail
# hadolint ignore=DL4006,SC2016
RUN <<EOF
  set -e

  # SpamAssassin: cron job, update hook and KAM channel key
  # ref: https://github.com/docker-mailserver/docker-mailserver/pull/3403#discussion_r1306282387
  echo 'CRON=1' >/etc/default/spamassassin
  sedfile -i -r 's/^\$INIT restart/supervisorctl restart amavis/g' /etc/spamassassin/sa-update-hooks.d/amavisd-new
  mkdir /etc/spamassassin/kam/
  curl -sSfLo /etc/spamassassin/kam/kam.sa-channels.mcgrail.com.key https://mcgrail.com/downloads/kam.sa-channels.mcgrail.com.key

  # Postgrey: run directory and client whitelist
  mkdir /var/run/postgrey
  chown postgrey:postgrey /var/run/postgrey
  curl -Lsfo /etc/postgrey/whitelist_clients https://raw.githubusercontent.com/schweikert/postgrey/master/postgrey_whitelist_clients

  # Amavis: enable the `bypass` settings of the content filter mode
  sedfile -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode

  # Users and groups
  # add users clamav and amavis to each others group
  adduser clamav amavis
  adduser amavis clamav
  # no syslog user in Debian compared to Ubuntu
  adduser --system syslog
  adduser docker --system --uid 5000 --group

  # Amavis: delete old quarantined virus mails (see `VIRUSMAILS_DELETE_DELAY`)
  echo "0 4 * * * /usr/local/bin/virus-wiper" | crontab -

  # postfix-mta-sts-daemon: run directory
  mkdir /var/run/mta-sts
  chown -R _mta-sts:root /var/run/mta-sts

  # Postfix: remove invalid URL from SPF message (https://bugs.launchpad.net/spf-engine/+bug/1896912)
  echo 'Reason_Message = Message {rejectdefer} due to: {spf}.' >>/etc/postfix-policyd-spf-python/policyd-spf.conf
  : >/etc/aliases

  # Fetchmail: start the daemon and provide its run directory
  sedfile -i 's/START_DAEMON=no/START_DAEMON=yes/g' /etc/default/fetchmail
  mkdir /var/run/fetchmail
  chown fetchmail /var/run/fetchmail
EOF

# -----------------------------------------------
# --- Logs --------------------------------------
# -----------------------------------------------

RUN <<EOF
  set -e

  # The logs of all services live in `/var/log/mail/`
  ln -s  /var/log/mail/mail.log     /var/log/mail.log
  ln -sf /var/log/mail/fail2ban.log /var/log/fail2ban.log

  sedfile -i -r "/^#?compress/c\compress\ncopytruncate" /etc/logrotate.conf
  mkdir /var/log/mail
  chown syslog:root /var/log/mail
  touch /var/log/mail/clamav.log
  chown -R clamav:root /var/log/mail/clamav.log
  touch /var/log/mail/freshclam.log
  chown -R clamav:root /var/log/mail/freshclam.log
  sedfile -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/rsyslog.conf
  sedfile -i -r 's|;auth,authpriv.none|;mail.none;mail.error;auth,authpriv.none|g' /etc/rsyslog.conf
  sedfile -i -r 's|LogFile /var/log/clamav/|LogFile /var/log/mail/|g' /etc/clamav/clamd.conf
  sedfile -i -r 's|UpdateLogFile /var/log/clamav/|UpdateLogFile /var/log/mail/|g' /etc/clamav/freshclam.conf
  sedfile -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-daemon
  sedfile -i -r 's|invoke-rc.d.*|/usr/bin/supervisorctl signal hup clamav >/dev/null \|\| true|g' /etc/logrotate.d/clamav-daemon
  sedfile -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-freshclam
  sedfile -i -r '/postrotate/,/endscript/d' /etc/logrotate.d/clamav-freshclam
  sedfile -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/logrotate.d/rsyslog
  sedfile -i -r '/\/var\/log\/mail\/mail.log/d' /etc/logrotate.d/rsyslog
  sedfile -i    's|^/var/log/fail2ban.log {$|/var/log/mail/fail2ban.log {|' /etc/logrotate.d/fail2ban
  # prevent syslog logrotate warnings
  sedfile -i -e 's/\(printerror "could not determine current runlevel"\)/#\1/' /usr/sbin/invoke-rc.d
  sedfile -i -e 's/^\(POLICYHELPER=\).*/\1/' /usr/sbin/invoke-rc.d
  # prevent syslog warning about imklog permissions
  sedfile -i -e 's/^module(load=\"imklog\")/#module(load=\"imklog\")/' /etc/rsyslog.conf
  # this change is for our alternative process manager rather than part of
  # a fix related to the change preceding it.
  printf '\n%s\n' '/usr/bin/supervisorctl signal hup rsyslog >/dev/null' >>/usr/lib/rsyslog/rsyslog-rotate
EOF

# `pidproxy` (used for Postfix) checks only every 5 seconds whether its child exited, which outlasts `startsecs`:
RUN sedfile -i 's/time.sleep(5)/time.sleep(0.2)/' /usr/lib/python3/dist-packages/supervisor/pidproxy.py

# -----------------------------------------------
# --- Configuration -----------------------------
# -----------------------------------------------

# `rootfs/` mirrors the filesystem of the container: every file is copied to the same path it has in the image (minus the `rootfs/` prefix).
# It is copied after the `RUN` instructions above, which only modify files shipped by the packages.
#
# DMS owns the complete Dovecot config (`build.sh` removed the one packaged by Debian / Dovecot CE):
# - `features/` holds the optional parts that are available. Startup copies the enabled ones to `features.d/`, which is empty until then.
# - `dovecot.conf` includes `features.d/*.conf` first and `conf.d/*.conf` afterwards, so user supplied files in `conf.d/` can override the features.
# - `masterdb` is the (empty) passdb of Dovecot master users, it is always included by `dovecot.conf`.
COPY rootfs/etc/ /etc/
RUN <<EOF
  set -e
  mkdir /etc/dovecot/conf.d /etc/dovecot/features.d
  install --mode 640 --owner dovecot --group dovecot /dev/null /etc/dovecot/masterdb
  chmod 0 /etc/cron.d/dovecot-purge.disabled
  chmod 644 /etc/amavis/conf.d/*
EOF

# -----------------------------------------------
# --- Scripts -----------------------------------
# -----------------------------------------------

# `rootfs/usr/local/bin/` holds the commands (in `PATH`), `rootfs/usr/local/lib/dms/` holds everything they and the startup sequence `source`.
COPY --chmod=755 rootfs/usr/local/ /usr/local/

#
# final stage focuses only on image config
#

FROM stage-main AS stage-final
ARG DMS_RELEASE=edge
ARG VCS_REVISION=unknown

WORKDIR /
EXPOSE 25 587 143 465 993 110 995 4190
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# These ENVs are referenced in the supervisor configs `rootfs/etc/supervisor/conf.d/dms-services.conf` (Postgrey, Fetchmail)
# and `rootfs/etc/supervisor/conf.d/saslauth.conf` (SASLAuthd) and must be present when supervisord starts. Introduced by PR:
# https://github.com/docker-mailserver/docker-mailserver/pull/676
# The defaults of the Postgrey and Fetchmail ENVs are also set in `rootfs/usr/local/lib/dms/startup/variables-stack.sh`.
ENV FETCHMAIL_POLL=300
ENV POSTGREY_AUTO_WHITELIST_CLIENTS=5
ENV POSTGREY_DELAY=300
ENV POSTGREY_MAX_AGE=35
ENV POSTGREY_TEXT="Delayed by Postgrey"
ENV SASLAUTHD_MECH_OPTIONS=""

# Add metadata to image:
LABEL org.opencontainers.image.title="docker-mailserver"
LABEL org.opencontainers.image.vendor="The Docker Mailserver Organization"
LABEL org.opencontainers.image.authors="The Docker Mailserver Organization on GitHub"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.description="A production-ready fullstack but simple containerized mail server that uses only configuration files, no SQL database."
LABEL org.opencontainers.image.url="https://github.com/docker-mailserver"
LABEL org.opencontainers.image.documentation="https://github.com/docker-mailserver/docker-mailserver/blob/master/README.md"
LABEL org.opencontainers.image.source="https://github.com/docker-mailserver/docker-mailserver"
# ARG invalidates cache when it is used by a layer (implicitly affects RUN)
# Thus to maximize cache, keep these lines last:
LABEL org.opencontainers.image.revision=${VCS_REVISION}
LABEL org.opencontainers.image.version=${DMS_RELEASE}
ENV DMS_RELEASE=${DMS_RELEASE}
