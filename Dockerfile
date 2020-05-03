FROM debian:buster-slim

ARG VCS_REF
ARG VCS_VERSION

LABEL maintainer="Thomas VIAL"  \
    org.label-schema.name="docker-mailserver" \
    org.label-schema.description="A fullstack but simple mailserver (smtp, imap, antispam, antivirus, ssl...)" \
    org.label-schema.url="https://github.com/tomav/docker-mailserver" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/tomav/docker-mailserver" \
    org.label-schema.version=$VCS_VERSION \
    org.label-schema.schema-version="1.0"

ARG DEBIAN_FRONTEND=noninteractive
ENV VIRUSMAILS_DELETE_DELAY=7
ENV ONE_DIR=0
ENV ENABLE_POSTGREY=0
ENV FETCHMAIL_POLL=300
ENV POSTGREY_DELAY=300
ENV POSTGREY_MAX_AGE=35
ENV POSTGREY_AUTO_WHITELIST_CLIENTS=5
ENV POSTGREY_TEXT="Delayed by postgrey"

ENV SASLAUTHD_MECHANISMS=pam
ENV SASLAUTHD_MECH_OPTIONS=""

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Packages
# hadolint ignore=DL3015,DL3005
RUN \
  apt-get update -q --fix-missing && \
  apt-get -y upgrade && \
  apt-get -y install postfix && \
  apt-get -y install --no-install-recommends \
    altermime \
    amavisd-new \
    apt-transport-https \
    arj \
    binutils \
    bzip2 \
    ca-certificates \
    cabextract \
    clamav \
    clamav-daemon \
    cpio \
    curl \
    ed \
    fail2ban \
    fetchmail \
    file \
    gamin \
    gzip \
    gnupg \
    iproute2 \
    iptables \
    locales \
    logwatch \
    lhasa \
    libdate-manip-perl \
    liblz4-tool \
    libmail-spf-perl \
    libnet-dns-perl \
    libsasl2-modules \
    lrzip \
    lzop \
    netcat-openbsd \
    nomarch \
    opendkim \
    opendkim-tools \
    opendmarc \
    pax \
    pflogsumm \
    p7zip-full \
    postfix-ldap \
    postfix-pcre \
    postfix-policyd-spf-python \
    postsrsd \
    pyzor \
    razor \
    rpm2cpio \
    rsyslog \
    sasl2-bin \
    spamassassin \
    supervisor \
    postgrey \
    unrar-free \
    unzip \
    whois \
    xz-utils \
  # use Dovecot community repo to react faster on security updates
  #curl https://repo.dovecot.org/DOVECOT-REPO-GPG | gpg --import && \
  #gpg --export ED409DA1 > /etc/apt/trusted.gpg.d/dovecot.gpg && \
  #echo "deb https://repo.dovecot.org/ce-2.3-latest/debian/stretch stretch main" > /etc/apt/sources.list.d/dovecot-community.list && \
  #apt-get update -q --fix-missing && \
  #apt-get -y install --no-install-recommends \
    dovecot-core \
    dovecot-imapd \
    dovecot-ldap \
    dovecot-lmtpd \
    dovecot-managesieved \
    dovecot-pop3d \
    dovecot-sieve \
    dovecot-solr \
    && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /usr/share/locale/* && \
  rm -rf /usr/share/man/* && \
  rm -rf /usr/share/doc/* && \
  touch /var/log/auth.log && \
  update-locale && \
  rm /etc/postsrsd.secret && \
  rm /etc/cron.daily/00logwatch

RUN echo "0 */6 * * * clamav /usr/bin/freshclam --quiet" > /etc/cron.d/clamav-freshclam && \
  chmod 644 /etc/clamav/freshclam.conf && \
  freshclam && \
  sed -i 's/Foreground false/Foreground true/g' /etc/clamav/clamd.conf && \
  mkdir /var/run/clamav && \
  chown -R clamav:root /var/run/clamav && \
  rm -rf /var/log/clamav/

# Configures Dovecot
COPY target/dovecot/auth-passwdfile.inc target/dovecot/??-*.conf /etc/dovecot/conf.d/
COPY target/dovecot/scripts/quota-warning.sh /usr/local/bin/quota-warning.sh
COPY target/dovecot/sieve/* /usr/lib/dovecot/sieve-global/
WORKDIR /usr/share/dovecot
# hadolint ignore=SC2016,SC2086
RUN sed -i -e 's/include_try \/usr\/share\/dovecot\/protocols\.d/include_try \/etc\/dovecot\/protocols\.d/g' /etc/dovecot/dovecot.conf && \
  sed -i -e 's/#mail_plugins = \$mail_plugins/mail_plugins = \$mail_plugins sieve/g' /etc/dovecot/conf.d/15-lda.conf && \
  sed -i -e 's/^.*lda_mailbox_autocreate.*/lda_mailbox_autocreate = yes/g' /etc/dovecot/conf.d/15-lda.conf && \
  sed -i -e 's/^.*lda_mailbox_autosubscribe.*/lda_mailbox_autosubscribe = yes/g' /etc/dovecot/conf.d/15-lda.conf && \
  sed -i -e 's/^.*postmaster_address.*/postmaster_address = '${POSTMASTER_ADDRESS:="postmaster@domain.com"}'/g' /etc/dovecot/conf.d/15-lda.conf && \
  sed -i 's/#imap_idle_notify_interval = 2 mins/imap_idle_notify_interval = 29 mins/' /etc/dovecot/conf.d/20-imap.conf && \
  # Adapt mkcert for Dovecot community repo
  sed -i 's/CERTDIR=.*/CERTDIR=\/etc\/dovecot\/ssl/g' /usr/share/dovecot/mkcert.sh && \
  sed -i 's/KEYDIR=.*/KEYDIR=\/etc\/dovecot\/ssl/g' /usr/share/dovecot/mkcert.sh && \
  sed -i 's/KEYFILE=.*/KEYFILE=\$KEYDIR\/dovecot.key/g' /usr/share/dovecot/mkcert.sh && \
  # create directory for certificates created by mkcert
  mkdir /etc/dovecot/ssl && \
  chmod 755 /etc/dovecot/ssl  && \
  ./mkcert.sh  && \
  mkdir -p /usr/lib/dovecot/sieve-pipe /usr/lib/dovecot/sieve-filter /usr/lib/dovecot/sieve-global && \
  chmod 755 -R /usr/lib/dovecot/sieve-pipe /usr/lib/dovecot/sieve-filter /usr/lib/dovecot/sieve-global

# Configures LDAP
COPY target/dovecot/dovecot-ldap.conf.ext /etc/dovecot
COPY target/postfix/ldap-users.cf target/postfix/ldap-groups.cf target/postfix/ldap-aliases.cf target/postfix/ldap-domains.cf /etc/postfix/

# Enables Spamassassin CRON updates and update hook for supervisor
# hadolint ignore=SC2016
RUN sed -i -r 's/^(CRON)=0/\1=1/g' /etc/default/spamassassin && \
    sed -i -r 's/^\$INIT restart/supervisorctl restart amavis/g' /etc/spamassassin/sa-update-hooks.d/amavisd-new

# Enables Postgrey
COPY target/postgrey/postgrey /etc/default/postgrey
COPY target/postgrey/postgrey.init /etc/init.d/postgrey
RUN chmod 755 /etc/init.d/postgrey && \
  mkdir /var/run/postgrey && \
  chown postgrey:postgrey /var/run/postgrey

# Copy PostSRSd Config
COPY target/postsrsd/postsrsd /etc/default/postsrsd

# Copy shared ffdhe params
COPY target/shared/ffdhe4096.pem /etc/postfix/shared/ffdhe4096.pem

# Enables Amavis
COPY target/amavis/conf.d/* /etc/amavis/conf.d/
RUN sed -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode && \
  adduser clamav amavis && \
  adduser amavis clamav && \
  # no syslog user in debian compared to ubuntu
  adduser --system syslog && \
  useradd -u 5000 -d /home/docker -s /bin/bash -p "$(echo docker | openssl passwd -1 -stdin)" docker && \
  echo "0 4 * * * /usr/local/bin/virus-wiper" | crontab -

# Configure Fail2ban
COPY target/fail2ban/jail.conf /etc/fail2ban/jail.conf
COPY target/fail2ban/filter.d/postfix-sasl.conf /etc/fail2ban/filter.d/postfix-sasl.conf
RUN mkdir /var/run/fail2ban

# Enables Pyzor and Razor
RUN su - amavis -c "razor-admin -create && \
  razor-admin -register"

# Configure DKIM (opendkim)
# DKIM config files
COPY target/opendkim/opendkim.conf /etc/opendkim.conf
COPY target/opendkim/default-opendkim /etc/default/opendkim

# Configure DMARC (opendmarc)
COPY target/opendmarc/opendmarc.conf /etc/opendmarc.conf
COPY target/opendmarc/default-opendmarc /etc/default/opendmarc
COPY target/opendmarc/ignore.hosts /etc/opendmarc/ignore.hosts

# Configure fetchmail
COPY target/fetchmail/fetchmailrc /etc/fetchmailrc_general
RUN sed -i 's/START_DAEMON=no/START_DAEMON=yes/g' /etc/default/fetchmail
RUN mkdir /var/run/fetchmail && chown fetchmail /var/run/fetchmail

# Configures Postfix
COPY target/postfix/main.cf target/postfix/master.cf /etc/postfix/
COPY target/postfix/header_checks.pcre target/postfix/sender_header_filter.pcre target/postfix/sender_login_maps.pcre /etc/postfix/maps/
RUN echo "" > /etc/aliases

# Configuring Logs
RUN sed -i -r "/^#?compress/c\compress\ncopytruncate" /etc/logrotate.conf && \
  mkdir -p /var/log/mail && \
  chown syslog:root /var/log/mail && \
  touch /var/log/mail/clamav.log && \
  chown -R clamav:root /var/log/mail/clamav.log && \
  touch /var/log/mail/freshclam.log && \
  chown -R clamav:root /var/log/mail/freshclam.log && \
  sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/rsyslog.conf && \
  sed -i -r 's|;auth,authpriv.none|;mail.none;mail.error;auth,authpriv.none|g' /etc/rsyslog.conf && \
  sed -i -r 's|LogFile /var/log/clamav/|LogFile /var/log/mail/|g' /etc/clamav/clamd.conf && \
  sed -i -r 's|UpdateLogFile /var/log/clamav/|UpdateLogFile /var/log/mail/|g' /etc/clamav/freshclam.conf && \
  sed -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-daemon && \
  sed -i -r 's|invoke-rc.d.*|/usr/bin/supervisorctl signal hup clamav >/dev/null \|\| true|g' /etc/logrotate.d/clamav-daemon && \
  sed -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-freshclam && \
  sed -i -r 's|invoke-rc.d|#invoke-rc.d|g' /etc/logrotate.d/clamav-freshclam && \
  sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/logrotate.d/rsyslog && \
  sed -i -r '/\/var\/log\/mail\/mail.log/d' /etc/logrotate.d/rsyslog && \
  # prevent syslog logrotate warnings \
  sed -i -e 's/\(printerror "could not determine current runlevel"\)/#\1/' /usr/sbin/invoke-rc.d && \
  sed -i -e 's/^\(POLICYHELPER=\).*/\1/' /usr/sbin/invoke-rc.d && \
  # prevent email when /sbin/init or init system is not existing \
  sed -i -e 's|invoke-rc.d rsyslog rotate > /dev/null|/usr/bin/supervisorctl signal hup rsyslog >/dev/null|g' /usr/lib/rsyslog/rsyslog-rotate

# Get LetsEncrypt signed certificate
RUN curl -s https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x3-cross-signed.pem

COPY ./target/bin /usr/local/bin
# Start-mailserver script
COPY ./target/helper_functions.sh ./target/check-for-changes.sh ./target/start-mailserver.sh ./target/fail2ban-wrapper.sh ./target/postfix-wrapper.sh ./target/postsrsd-wrapper.sh ./target/docker-configomat/configomat.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*

# Configure supervisor
COPY target/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY target/supervisor/conf.d/* /etc/supervisor/conf.d/

WORKDIR /

# Switch iptables and ip6tables to legacy for fail2ban
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy \
 && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy


EXPOSE 25 587 143 465 993 110 995 4190

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
