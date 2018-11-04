FROM debian:stretch-slim
LABEL maintainer="Thomas VIAL"

ENV DEBIAN_FRONTEND noninteractive
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

# Packages
RUN apt-get update -q --fix-missing && \
  apt-get -y upgrade && \
  apt-get -y install postfix && \
  apt-get -y install --no-install-recommends \
    amavisd-new \
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
    ripole \
    rpm2cpio \
    rsyslog \
    sasl2-bin \
    spamassassin \
    supervisor \
    postgrey \
    unrar-free \
    unzip \
    xz-utils \
    zoo \
    && \
  curl https://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add - && \
  echo "deb http://packages.elastic.co/beats/apt stable main" | tee -a /etc/apt/sources.list.d/beats.list && \
  echo "deb http://ftp.debian.org/debian stretch-backports main" | tee -a /etc/apt/sources.list.d/stretch-bp.list && \
  apt-get update -q --fix-missing && \
  apt-get -y upgrade \
    filebeat \
    && \
  apt-get -t stretch-backports -y install --no-install-recommends \
    dovecot-core \
    dovecot-imapd \
    dovecot-ldap \
    dovecot-lmtpd \
    dovecot-managesieved \
    dovecot-pop3d \
    dovecot-sieve \
    && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /usr/share/locale/* && \
  rm -rf /usr/share/man/* && \
  rm -rf /usr/share/doc/* && \
  touch /var/log/auth.log && \
  update-locale && \
  rm -f /etc/cron.weekly/fstrim && \
  rm -f /etc/postsrsd.secret

RUN echo "0 0,6,12,18 * * * /usr/bin/freshclam --quiet" > /etc/cron.d/clamav-freshclam && \
  chmod 644 /etc/clamav/freshclam.conf && \
  freshclam && \
  sed -i 's/Foreground false/Foreground true/g' /etc/clamav/clamd.conf && \
  sed -i 's/AllowSupplementaryGroups false/AllowSupplementaryGroups true/g' /etc/clamav/clamd.conf && \
  mkdir /var/run/clamav && \
  chown -R clamav:root /var/run/clamav

# Configures Dovecot
COPY target/dovecot/auth-passwdfile.inc target/dovecot/??-*.conf /etc/dovecot/conf.d/
RUN sed -i -e 's/include_try \/usr\/share\/dovecot\/protocols\.d/include_try \/etc\/dovecot\/protocols\.d/g' /etc/dovecot/dovecot.conf && \
  sed -i -e 's/#mail_plugins = \$mail_plugins/mail_plugins = \$mail_plugins sieve/g' /etc/dovecot/conf.d/15-lda.conf && \
  sed -i -e 's/^.*lda_mailbox_autocreate.*/lda_mailbox_autocreate = yes/g' /etc/dovecot/conf.d/15-lda.conf && \
  sed -i -e 's/^.*lda_mailbox_autosubscribe.*/lda_mailbox_autosubscribe = yes/g' /etc/dovecot/conf.d/15-lda.conf && \
  sed -i -e 's/^.*postmaster_address.*/postmaster_address = '${POSTMASTER_ADDRESS:="postmaster@domain.com"}'/g' /etc/dovecot/conf.d/15-lda.conf && \
  sed -i 's/#imap_idle_notify_interval = 2 mins/imap_idle_notify_interval = 29 mins/' /etc/dovecot/conf.d/20-imap.conf && \
  # stretch-backport of dovecot needs this folder
  mkdir /etc/dovecot/ssl && \
  chmod 755 /etc/dovecot/ssl  && \
  cd /usr/share/dovecot && \
  ./mkcert.sh  && \
  mkdir -p /usr/lib/dovecot/sieve-pipe /usr/lib/dovecot/sieve-filter /usr/lib/dovecot/sieve-global && \
  chmod 755 -R /usr/lib/dovecot/sieve-pipe /usr/lib/dovecot/sieve-filter /usr/lib/dovecot/sieve-global

# Configures LDAP
COPY target/dovecot/dovecot-ldap.conf.ext /etc/dovecot
COPY target/postfix/ldap-users.cf target/postfix/ldap-groups.cf target/postfix/ldap-aliases.cf target/postfix/ldap-domains.cf /etc/postfix/

# Enables Spamassassin CRON updates and update hook for supervisor
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

# Enables Amavis
COPY target/amavis/conf.d/* /etc/amavis/conf.d/
RUN sed -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode && \
  adduser clamav amavis && \
  adduser amavis clamav && \
  # no syslog user in debian compared to ubuntu
  adduser --system syslog && \
  useradd -u 5000 -d /home/docker -s /bin/bash -p $(echo docker | openssl passwd -1 -stdin) docker && \
  (echo "0 4 * * * /usr/local/bin/virus-wiper" ; crontab -l) | crontab -

# Configure Fail2ban
COPY target/fail2ban/jail.conf /etc/fail2ban/jail.conf
COPY target/fail2ban/filter.d/dovecot.conf /etc/fail2ban/filter.d/dovecot.conf
RUN echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf && mkdir /var/run/fail2ban

# Enables Pyzor and Razor
USER amavis
RUN razor-admin -create && \
  razor-admin -register
USER root

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
RUN echo "" > /etc/aliases && \
  openssl dhparam -out /etc/postfix/dhparams.pem 2048 && \
  echo "@weekly FILE=`mktemp` ; openssl dhparam -out $FILE 2048 > /dev/null 2>&1 && mv -f $FILE /etc/postfix/dhparams.pem" > /etc/cron.d/dh2048


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
  sed -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-freshclam && \
  sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/logrotate.d/rsyslog && \
  sed -i -r '/\/var\/log\/mail\/mail.log/d' /etc/logrotate.d/rsyslog && \
  # prevent syslog logrotate warnings \
  sed -i -e 's/\(printerror "could not determine current runlevel"\)/#\1/' /usr/sbin/invoke-rc.d && \
  sed -i -e 's/^\(POLICYHELPER=\).*/\1/' /usr/sbin/invoke-rc.d && \
  # prevent email when /sbin/init or init system is not existing \
  sed -i -e 's/invoke-rc.d rsyslog rotate > \/dev\/null/invoke-rc.d rsyslog --quiet rotate > \/dev\/null/g' /etc/logrotate.d/rsyslog

# Get LetsEncrypt signed certificate
RUN curl -s https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x3-cross-signed.pem

COPY ./target/bin /usr/local/bin
# Start-mailserver script
COPY ./target/check-for-changes.sh ./target/start-mailserver.sh ./target/fail2ban-wrapper.sh ./target/postfix-wrapper.sh ./target/postsrsd-wrapper.sh ./target/docker-configomat/configomat.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*

# Configure supervisor
COPY target/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY target/supervisor/conf.d/* /etc/supervisor/conf.d/

EXPOSE 25 587 143 465 993 110 995 4190

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

ADD target/filebeat.yml.tmpl /etc/filebeat/filebeat.yml.tmpl
