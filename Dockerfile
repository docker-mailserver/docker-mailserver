# syntax=docker.io/docker/dockerfile:1

# This Dockerfile provides four stages: stage-base, stage-compile, stage-main and stage-final
# This is in preparation for more granular stages (eg ClamAV and Fail2Ban split into their own)

ARG DEBIAN_FRONTEND=noninteractive
ARG DOVECOT_COMMUNITY_REPO=1
ARG LOG_LEVEL=trace

FROM docker.io/debian:12-slim AS stage-base

ARG DEBIAN_FRONTEND
ARG DOVECOT_COMMUNITY_REPO
ARG LOG_LEVEL

SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]

# -----------------------------------------------
# --- Install Basic Software --------------------
# -----------------------------------------------

COPY target/bin/sedfile /usr/local/bin/sedfile
RUN <<EOF
  chmod +x /usr/local/bin/sedfile
  adduser --quiet --system --group --disabled-password --home /var/lib/clamav --no-create-home --uid 200 clamav
EOF

COPY target/scripts/build/packages.sh /build/
COPY target/scripts/helpers/log.sh /usr/local/bin/helpers/log.sh

RUN /bin/bash /build/packages.sh && rm -r /build



# -----------------------------------------------
# --- Compile deb packages ----------------------
# -----------------------------------------------

FROM stage-base AS stage-compile

ARG LOG_LEVEL
ARG DEBIAN_FRONTEND

COPY target/scripts/build/compile.sh /build/
RUN /bin/bash /build/compile.sh

#
# main stage provides all packages, config, and adds scripts
#

FROM stage-base AS stage-main

ARG DEBIAN_FRONTEND
ARG LOG_LEVEL

SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]


# -----------------------------------------------
# --- ClamAV & FeshClam -------------------------
# -----------------------------------------------

# Copy over latest DB updates from official ClamAV image. This is better than running `freshclam`,
# which would require an extra memory of 500MB+ during an image build.
# When using `COPY --link`, the `--chown` option is only compatible with numeric ID values.
# hadolint ignore=DL3021
COPY --link --chown=200 --from=docker.io/clamav/clamav:latest /var/lib/clamav /var/lib/clamav

RUN <<EOF
  # `COPY --link --chown=200` has a bug when built by the buildx docker-container driver.
  # Restore ownership of parent dirs (Bug: https://github.com/moby/buildkit/issues/3912)
  chown root:root /var /var/lib
  echo '0 */6 * * * clamav /usr/bin/freshclam --quiet' >/etc/cron.d/clamav-freshclam
  chmod 644 /etc/clamav/freshclam.conf
  sedfile -i 's/Foreground false/Foreground true/g' /etc/clamav/clamd.conf
  mkdir /var/run/clamav
  chown -R clamav:root /var/run/clamav
  rm -rf /var/log/clamav/
EOF

# -----------------------------------------------
# --- Dovecot -----------------------------------
# -----------------------------------------------

# install fts_xapian plugin

COPY --from=stage-compile dovecot-fts-xapian-1.5.5_1.5.5_*.deb /
RUN dpkg -i /dovecot-fts-xapian-1.5.5_1.5.5_*.deb && rm /dovecot-fts-xapian-1.5.5_1.5.5_*.deb

COPY target/dovecot/*.inc target/dovecot/*.conf /etc/dovecot/conf.d/
COPY target/dovecot/dovecot-purge.cron /etc/cron.d/dovecot-purge.disabled
RUN chmod 0 /etc/cron.d/dovecot-purge.disabled
WORKDIR /usr/share/dovecot

# hadolint ignore=SC2016,SC2086,SC2069
RUN <<EOF
  sedfile -i -e 's/include_try \/usr\/share\/dovecot\/protocols\.d/include_try \/etc\/dovecot\/protocols\.d/g' /etc/dovecot/dovecot.conf
  sedfile -i -e 's/#mail_plugins = \$mail_plugins/mail_plugins = \$mail_plugins sieve/g' /etc/dovecot/conf.d/15-lda.conf
  sedfile -i -e 's/^.*lda_mailbox_autocreate.*/lda_mailbox_autocreate = yes/g' /etc/dovecot/conf.d/15-lda.conf
  sedfile -i -e 's/^.*lda_mailbox_autosubscribe.*/lda_mailbox_autosubscribe = yes/g' /etc/dovecot/conf.d/15-lda.conf
  sedfile -i -e 's/^.*postmaster_address.*/postmaster_address = '${POSTMASTER_ADDRESS:="postmaster@domain.com"}'/g' /etc/dovecot/conf.d/15-lda.conf
EOF

# -----------------------------------------------
# --- Rspamd ------------------------------------
# -----------------------------------------------

COPY target/rspamd/local.d/ /etc/rspamd/local.d/

# -----------------------------------------------
# --- LDAP & SpamAssassin's Cron ----------------
# -----------------------------------------------

COPY target/dovecot/dovecot-ldap.conf.ext /etc/dovecot
COPY \
  target/postfix/ldap-users.cf \
  target/postfix/ldap-groups.cf \
  target/postfix/ldap-aliases.cf \
  target/postfix/ldap-domains.cf \
  target/postfix/ldap-senders.cf \
  /etc/postfix/

# hadolint ignore=SC2016
RUN <<EOF
  sedfile -i -r 's/^(CRON)=0/\1=1/g' /etc/default/spamassassin
  sedfile -i -r 's/^\$INIT restart/supervisorctl restart amavis/g' /etc/spamassassin/sa-update-hooks.d/amavisd-new
  mkdir /etc/spamassassin/kam/
  curl -sSfLo /etc/spamassassin/kam/kam.sa-channels.mcgrail.com.key https://mcgrail.com/downloads/kam.sa-channels.mcgrail.com.key
EOF

# -----------------------------------------------
# --- PostSRSD, Postgrey & Amavis ---------------
# -----------------------------------------------

COPY target/postsrsd/postsrsd /etc/default/postsrsd
COPY target/postgrey/postgrey /etc/default/postgrey
COPY target/postgrey/postgrey.init /etc/init.d/postgrey
RUN <<EOF
  chmod 755 /etc/init.d/postgrey
  mkdir /var/run/postgrey
  chown postgrey:postgrey /var/run/postgrey
  curl -Lsfo /etc/postgrey/whitelist_clients https://postgrey.schweikert.ch/pub/postgrey_whitelist_clients
EOF

COPY target/amavis/conf.d/* /etc/amavis/conf.d/
COPY target/amavis/postfix-amavis.cf /etc/dms/postfix/master.d/
RUN <<EOF
  sedfile -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode
  # add users clamav and amavis to each others group
  adduser clamav amavis
  adduser amavis clamav
  # no syslog user in Debian compared to Ubuntu
  adduser --system syslog
  useradd -u 5000 -d /home/docker -s /bin/bash -p "$(echo docker | openssl passwd -1 -stdin)" docker
  echo "0 4 * * * /usr/local/bin/virus-wiper" | crontab -
  chmod 644 /etc/amavis/conf.d/*
EOF

# overcomplication necessary for CI
# hadolint ignore=SC2086
RUN <<EOF
  for _ in {1..10}; do
    su - amavis -c "razor-admin -create"
    sleep 3
    if su - amavis -c "razor-admin -register"; then
      EC=0
      break
    else
      EC=${?}
    fi
  done
  exit ${EC}
EOF

# -----------------------------------------------
# --- Fail2Ban, DKIM & DMARC --------------------
# -----------------------------------------------

COPY target/fail2ban/jail.local /etc/fail2ban/jail.local
COPY target/fail2ban/fail2ban.d/fixes.local /etc/fail2ban/fail2ban.d/fixes.local
RUN <<EOF
  ln -s  /var/log/mail/mail.log     /var/log/mail.log
  ln -sf /var/log/mail/fail2ban.log /var/log/fail2ban.log
  # disable sshd jail
  rm /etc/fail2ban/jail.d/defaults-debian.conf
  mkdir /var/run/fail2ban
EOF

COPY target/opendkim/opendkim.conf /etc/opendkim.conf
COPY target/opendkim/default-opendkim /etc/default/opendkim

COPY target/opendmarc/opendmarc.conf /etc/opendmarc.conf
COPY target/opendmarc/default-opendmarc /etc/default/opendmarc
COPY target/opendmarc/ignore.hosts /etc/opendmarc/ignore.hosts

# --------------------------------------------------
# --- Fetchmail, Getmail, Postfix & Let'sEncrypt ---
# --------------------------------------------------

# Remove invalid URL from SPF message
# https://bugs.launchpad.net/spf-engine/+bug/1896912
RUN echo 'Reason_Message = Message {rejectdefer} due to: {spf}.' >>/etc/postfix-policyd-spf-python/policyd-spf.conf

COPY target/fetchmail/fetchmailrc /etc/fetchmailrc_general
COPY target/getmail/getmailrc /etc/getmailrc_general
COPY target/postfix/main.cf target/postfix/master.cf /etc/postfix/

# DH parameters for DHE cipher suites, ffdhe4096 is the official standard 4096-bit DH params now part of TLS 1.3
# This file is for TLS <1.3 handshakes that rely on DHE cipher suites
# Handled at build to avoid failures by doveadm validating ssl_dh filepath in 10-ssl.auth (eg generate-accounts)
COPY target/shared/ffdhe4096.pem /etc/postfix/dhparams.pem
COPY target/shared/ffdhe4096.pem /etc/dovecot/dh.pem

COPY \
  target/postfix/header_checks.pcre \
  target/postfix/sender_header_filter.pcre \
  target/postfix/sender_login_maps.pcre \
  /etc/postfix/maps/

RUN <<EOF
  : >/etc/aliases
  sedfile -i 's/START_DAEMON=no/START_DAEMON=yes/g' /etc/default/fetchmail
  mkdir /var/run/fetchmail && chown fetchmail /var/run/fetchmail
EOF

# -----------------------------------------------
# --- Logs --------------------------------------
# -----------------------------------------------

RUN <<EOF
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
  # prevent email when /sbin/init or init system is not existing
  sedfile -i -e 's|invoke-rc.d rsyslog rotate > /dev/null|/usr/bin/supervisorctl signal hup rsyslog >/dev/null|g' /usr/lib/rsyslog/rsyslog-rotate
EOF

# -----------------------------------------------
# --- Logwatch ----------------------------------
# -----------------------------------------------

COPY target/logwatch/maillog.conf /etc/logwatch/conf/logfiles/maillog.conf

# -----------------------------------------------
# --- Supervisord & Start -----------------------
# -----------------------------------------------

COPY target/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY target/supervisor/conf.d/* /etc/supervisor/conf.d/

# -----------------------------------------------
# --- Scripts & Miscellaneous--------------------
# -----------------------------------------------

RUN <<EOF
  rm -rf /usr/share/locale/*
  rm -rf /usr/share/man/*
  rm -rf /usr/share/doc/*
  update-locale
EOF

COPY VERSION /

COPY \
  target/bin/* \
  target/scripts/*.sh \
  target/scripts/startup/*.sh \
  /usr/local/bin/

RUN chmod +x /usr/local/bin/*

COPY target/scripts/helpers /usr/local/bin/helpers
COPY target/scripts/startup/setup.d /usr/local/bin/setup.d

#
# Final stage focuses only on image config
#

FROM stage-main AS stage-final
ARG VCS_REVISION=unknown
ARG VCS_VERSION=edge

WORKDIR /
EXPOSE 25 587 143 465 993 110 995 4190
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# These ENVs are referenced in target/supervisor/conf.d/saslauth.conf
# and must be present when supervisord starts. Introduced by PR:
# https://github.com/docker-mailserver/docker-mailserver/pull/676
# These ENV are also configured with the same defaults at:
# https://github.com/docker-mailserver/docker-mailserver/blob/672e9cf19a3bb1da309e8cea6ee728e58f905366/target/scripts/helpers/variables.sh
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
LABEL org.opencontainers.image.description="A fullstack but simple mail server (SMTP, IMAP, LDAP, Antispam, Antivirus, etc.). Only configuration files, no SQL database."
LABEL org.opencontainers.image.url="https://github.com/docker-mailserver"
LABEL org.opencontainers.image.documentation="https://github.com/docker-mailserver/docker-mailserver/blob/master/README.md"
LABEL org.opencontainers.image.source="https://github.com/docker-mailserver/docker-mailserver"
# ARG invalidates cache when it is used by a layer (implicitly affects RUN)
# Thus to maximize cache, keep these lines last:
LABEL org.opencontainers.image.revision=${VCS_REVISION}
LABEL org.opencontainers.image.version=${VCS_VERSION}
