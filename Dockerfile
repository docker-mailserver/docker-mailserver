FROM docker.io/debian:11-slim

ARG VCS_VER
ARG VCS_REF
ARG DEBIAN_FRONTEND=noninteractive

ARG FAIL2BAN_DEB_URL=https://github.com/fail2ban/fail2ban/releases/download/0.11.2/fail2ban_0.11.2-1.upstream1_all.deb
ARG FAIL2BAN_DEB_ASC_URL=${FAIL2BAN_DEB_URL}.asc
ARG FAIL2BAN_GPG_PUBLIC_KEY_ID=0x683BF1BEBD0A882C
ARG FAIL2BAN_GPG_PUBLIC_KEY_SERVER=hkps://keyserver.ubuntu.com
ARG FAIL2BAN_GPG_FINGERPRINT="8738 559E 26F6 71DF 9E2C  6D9E 683B F1BE BD0A 882C"

LABEL org.opencontainers.image.version=${VCS_VER}
LABEL org.opencontainers.image.revision=${VCS_REF}
LABEL org.opencontainers.image.title="docker-mailserver"
LABEL org.opencontainers.image.vendor="The Docker Mailserver Organization"
LABEL org.opencontainers.image.authors="The Docker Mailserver Organization on GitHub"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.description="A fullstack but simple mail server (SMTP, IMAP, LDAP, Antispam, Antivirus, etc.). Only configuration files, no SQL database."
LABEL org.opencontainers.image.url="https://github.com/docker-mailserver"
LABEL org.opencontainers.image.documentation="https://github.com/docker-mailserver/docker-mailserver/blob/master/README.md"
LABEL org.opencontainers.image.source="https://github.com/docker-mailserver/docker-mailserver"

# These ENVs are referenced in target/supervisor/conf.d/saslauth.conf
# and must be present when supervisord starts.
# If necessary, their values are adjusted by target/scripts/start-mailserver.sh on startup.
ENV FETCHMAIL_POLL=300
ENV POSTGREY_AUTO_WHITELIST_CLIENTS=5
ENV POSTGREY_DELAY=300
ENV POSTGREY_MAX_AGE=35
ENV POSTGREY_TEXT="Delayed by Postgrey"
ENV SASLAUTHD_MECH_OPTIONS=""

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# -----------------------------------------------
# --- Install Basic Software --------------------
# -----------------------------------------------

RUN \
  apt-get -qq update && \
  apt-get -qq install apt-utils 2>/dev/null && \
  apt-get -qq dist-upgrade && \
  echo "applying workaround for ubuntu/postfix bug described in https://github.com/docker-mailserver/docker-mailserver/issues/2023#issuecomment-855326403" && \
  mv /bin/hostname{,.bak} && \
  echo "echo docker-mailserver.invalid" > /bin/hostname && \
  chmod +x /bin/hostname && \
  apt-get -qq install postfix && \
  mv /bin/hostname{.bak,} && \
  apt-get -qq --no-install-recommends install \
  # A - D
  altermime amavisd-new apt-transport-https arj binutils bzip2 bsd-mailx \
  ca-certificates cabextract clamav clamav-daemon cpio curl \
  dbconfig-no-thanks dovecot-core dovecot-fts-xapian dovecot-imapd \
  dovecot-ldap dovecot-lmtpd dovecot-managesieved dovecot-pop3d \
  dovecot-sieve dovecot-solr dumb-init \
  # E - O
  ed fetchmail file gamin gnupg gzip iproute2 \
  locales logwatch lhasa libdate-manip-perl libldap-common liblz4-tool \
  libmail-spf-perl libnet-dns-perl libsasl2-modules lrzip lzop \
  netcat-openbsd nftables nomarch opendkim opendkim-tools opendmarc \
  # P - Z
  pax pflogsumm postgrey p7zip-full postfix-ldap postfix-pcre \
  postfix-policyd-spf-python postsrsd pyzor \
  razor rpm2cpio rsyslog sasl2-bin spamassassin supervisor \
  unrar-free unzip uuid whois xz-utils && \
  # Fail2Ban
  gpg --keyserver ${FAIL2BAN_GPG_PUBLIC_KEY_SERVER} \
    --recv-keys ${FAIL2BAN_GPG_PUBLIC_KEY_ID} 2>&1 && \
  curl -Lkso fail2ban.deb ${FAIL2BAN_DEB_URL} && \
  curl -Lkso fail2ban.deb.asc ${FAIL2BAN_DEB_ASC_URL} && \
  FINGERPRINT=$(LANG=C gpg --verify \
  fail2ban.deb.asc fail2ban.deb 2>&1 \
    | sed -n 's#Primary key fingerprint: \(.*\)#\1#p') && \
  if [[ -z ${FINGERPRINT} ]]; then \
    echo "ERROR: Invalid GPG signature!" >&2; exit 1; fi && \
  if [[ ${FINGERPRINT} != "${FAIL2BAN_GPG_FINGERPRINT}" ]]; then \
    echo "ERROR: Wrong GPG fingerprint!" >&2; exit 1; fi && \
  dpkg -i fail2ban.deb 2>&1 && \
  rm fail2ban.deb fail2ban.deb.asc && \
  # cleanup
  apt-get -qq autoremove && \
  apt-get -qq autoclean && \
  apt-get -qq clean && \
  rm -rf /var/lib/apt/lists/* && \
  c_rehash 2>&1

COPY ./target/scripts/helpers/log.sh /usr/local/bin/helpers/log.sh
COPY ./target/bin/sedfile /usr/local/bin/sedfile

RUN chmod +x /usr/local/bin/sedfile

# -----------------------------------------------
# --- ClamAV & FeshClam -------------------------
# -----------------------------------------------

RUN \
  echo '0 */6 * * * clamav /usr/bin/freshclam --quiet' >/etc/cron.d/clamav-freshclam && \
  chmod 644 /etc/clamav/freshclam.conf && \
  freshclam && \
  sedfile -i 's/Foreground false/Foreground true/g' /etc/clamav/clamd.conf && \
  mkdir /var/run/clamav && \
  chown -R clamav:root /var/run/clamav && \
  rm -rf /var/log/clamav/

# -----------------------------------------------
# --- Dovecot -----------------------------------
# -----------------------------------------------

COPY target/dovecot/auth-passwdfile.inc target/dovecot/auth-master.inc target/dovecot/??-*.conf /etc/dovecot/conf.d/
COPY target/dovecot/sieve/ /etc/dovecot/sieve/
COPY target/dovecot/dovecot-purge.cron /etc/cron.d/dovecot-purge.disabled
RUN chmod 0 /etc/cron.d/dovecot-purge.disabled
WORKDIR /usr/share/dovecot

# hadolint ignore=SC2016,SC2086,SC2069
RUN \
  sedfile -i -e 's/include_try \/usr\/share\/dovecot\/protocols\.d/include_try \/etc\/dovecot\/protocols\.d/g' /etc/dovecot/dovecot.conf && \
  sedfile -i -e 's/#mail_plugins = \$mail_plugins/mail_plugins = \$mail_plugins sieve/g' /etc/dovecot/conf.d/15-lda.conf && \
  sedfile -i -e 's/^.*lda_mailbox_autocreate.*/lda_mailbox_autocreate = yes/g' /etc/dovecot/conf.d/15-lda.conf && \
  sedfile -i -e 's/^.*lda_mailbox_autosubscribe.*/lda_mailbox_autosubscribe = yes/g' /etc/dovecot/conf.d/15-lda.conf && \
  sedfile -i -e 's/^.*postmaster_address.*/postmaster_address = '${POSTMASTER_ADDRESS:="postmaster@domain.com"}'/g' /etc/dovecot/conf.d/15-lda.conf && \
  mkdir -p /usr/lib/dovecot/sieve-pipe /usr/lib/dovecot/sieve-filter /usr/lib/dovecot/sieve-global && \
  chmod 755 -R /usr/lib/dovecot/sieve-pipe /usr/lib/dovecot/sieve-filter /usr/lib/dovecot/sieve-global

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
RUN \
  sedfile -i -r 's/^(CRON)=0/\1=1/g' /etc/default/spamassassin && \
  sedfile -i -r 's/^\$INIT restart/supervisorctl restart amavis/g' \
    /etc/spamassassin/sa-update-hooks.d/amavisd-new && \
  mkdir -p /etc/spamassassin/kam/ && \
  curl -sSfLo /etc/spamassassin/kam/kam.sa-channels.mcgrail.com.key \
    https://mcgrail.com/downloads/kam.sa-channels.mcgrail.com.key

# -----------------------------------------------
# --- PostSRSD, Postgrey & Amavis ---------------
# -----------------------------------------------

COPY target/postsrsd/postsrsd /etc/default/postsrsd
COPY target/postgrey/postgrey /etc/default/postgrey
COPY target/postgrey/postgrey.init /etc/init.d/postgrey
RUN \
  chmod 755 /etc/init.d/postgrey && \
  mkdir /var/run/postgrey && \
  chown postgrey:postgrey /var/run/postgrey && \
  curl -Lsfo /etc/postgrey/whitelist_clients https://postgrey.schweikert.ch/pub/postgrey_whitelist_clients

COPY target/amavis/conf.d/* /etc/amavis/conf.d/
RUN \
  sedfile -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode && \
  # add users clamav and amavis to each others group
  adduser clamav amavis && \
  adduser amavis clamav && \
  # no syslog user in Debian compared to Ubuntu
  adduser --system syslog && \
  useradd -u 5000 -d /home/docker -s /bin/bash -p "$(echo docker | openssl passwd -1 -stdin)" docker && \
  echo "0 4 * * * /usr/local/bin/virus-wiper" | crontab - && \
  chmod 644 /etc/amavis/conf.d/*

# overcomplication necessary for CI
RUN \
  for _ in {1..10}; do su - amavis -c "razor-admin -create" ; sleep 3 ; \
  if su - amavis -c "razor-admin -register" ; then { EC=0 ; break ; } ; \
  else EC=${?} ; fi ; done ; (exit ${EC})

# -----------------------------------------------
# --- Fail2Ban, DKIM & DMARC --------------------
# -----------------------------------------------

COPY target/fail2ban/jail.local /etc/fail2ban/jail.local
RUN \
  ln -s /var/log/mail/mail.log /var/log/mail.log && \
  # disable sshd jail
  rm /etc/fail2ban/jail.d/defaults-debian.conf && \
  mkdir /var/run/fail2ban

COPY target/opendkim/opendkim.conf /etc/opendkim.conf
COPY target/opendkim/default-opendkim /etc/default/opendkim

COPY target/opendmarc/opendmarc.conf /etc/opendmarc.conf
COPY target/opendmarc/default-opendmarc /etc/default/opendmarc
COPY target/opendmarc/ignore.hosts /etc/opendmarc/ignore.hosts

# -----------------------------------------------
# --- Fetchmail, Postfix & Let'sEncrypt ---------
# -----------------------------------------------

# Remove invalid URL from SPF message
# https://bugs.launchpad.net/spf-engine/+bug/1896912
RUN echo 'Reason_Message = Message {rejectdefer} due to: {spf}.' >>/etc/postfix-policyd-spf-python/policyd-spf.conf

COPY target/fetchmail/fetchmailrc /etc/fetchmailrc_general
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

RUN \
  : >/etc/aliases && \
  sedfile -i 's/START_DAEMON=no/START_DAEMON=yes/g' /etc/default/fetchmail && \
  mkdir /var/run/fetchmail && chown fetchmail /var/run/fetchmail

# -----------------------------------------------
# --- Logs --------------------------------------
# -----------------------------------------------

RUN \
  sedfile -i -r "/^#?compress/c\compress\ncopytruncate" /etc/logrotate.conf && \
  mkdir -p /var/log/mail && \
  chown syslog:root /var/log/mail && \
  touch /var/log/mail/clamav.log && \
  chown -R clamav:root /var/log/mail/clamav.log && \
  touch /var/log/mail/freshclam.log && \
  chown -R clamav:root /var/log/mail/freshclam.log && \
  sedfile -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/rsyslog.conf && \
  sedfile -i -r 's|;auth,authpriv.none|;mail.none;mail.error;auth,authpriv.none|g' /etc/rsyslog.conf && \
  sedfile -i -r 's|LogFile /var/log/clamav/|LogFile /var/log/mail/|g' /etc/clamav/clamd.conf && \
  sedfile -i -r 's|UpdateLogFile /var/log/clamav/|UpdateLogFile /var/log/mail/|g' /etc/clamav/freshclam.conf && \
  sedfile -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-daemon && \
  sedfile -i -r 's|invoke-rc.d.*|/usr/bin/supervisorctl signal hup clamav >/dev/null \|\| true|g' /etc/logrotate.d/clamav-daemon && \
  sedfile -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-freshclam && \
  sedfile -i -r '/postrotate/,/endscript/d' /etc/logrotate.d/clamav-freshclam && \
  sedfile -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/logrotate.d/rsyslog && \
  sedfile -i -r '/\/var\/log\/mail\/mail.log/d' /etc/logrotate.d/rsyslog && \
  # prevent syslog logrotate warnings
  sedfile -i -e 's/\(printerror "could not determine current runlevel"\)/#\1/' /usr/sbin/invoke-rc.d && \
  sedfile -i -e 's/^\(POLICYHELPER=\).*/\1/' /usr/sbin/invoke-rc.d && \
  # prevent syslog warning about imklog permissions
  sedfile -i -e 's/^module(load=\"imklog\")/#module(load=\"imklog\")/' /etc/rsyslog.conf && \
  # prevent email when /sbin/init or init system is not existing
  sedfile -i -e 's|invoke-rc.d rsyslog rotate > /dev/null|/usr/bin/supervisorctl signal hup rsyslog >/dev/null|g' /usr/lib/rsyslog/rsyslog-rotate

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

RUN \
  rm -rf /usr/share/locale/* && \
  rm -rf /usr/share/man/* && \
  rm -rf /usr/share/doc/* && \
  touch /var/log/auth.log && \
  update-locale && \
  rm /etc/postsrsd.secret && \
  rm /etc/cron.daily/00logwatch

COPY ./VERSION /

COPY \
  ./target/bin/* \
  ./target/scripts/*.sh \
  ./target/scripts/startup/*.sh \
  ./target/scripts/wrapper/*.sh \
  ./target/docker-configomat/configomat.sh \
  /usr/local/bin/

RUN chmod +x /usr/local/bin/*

COPY ./target/scripts/helpers /usr/local/bin/helpers

WORKDIR /

EXPOSE 25 587 143 465 993 110 995 4190

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
