FROM gliderlabs/alpine:3.3
MAINTAINER Thomas VIAL

# Packages
RUN apk add --no-cache \
      amavisd-new \
      # bash until start-mailserver.sh is ported so /bin/sh, if it can be
      bash \
      clamav \
      clamav-daemon \
      # clamav-dev is needed for libclamunrar_iface.so
      clamav-dev \
      curl \
      dovecot \
      fail2ban \
      freshclam \
      postfix \
      rsyslog \
      spamassassin

#################################
# opendkim is not in the edge repo.
# dkimproxy is in main, is it a replacemnts?
# https://pkgs.alpinelinux.org/package/v3.3/main/x86/dkimproxy
#RUN apk add opendkim --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted
#################################
RUN apk add shadow --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted

# Configures Dovecot
RUN sed -i -e 's/include_try \/usr\/share\/dovecot\/protocols\.d/include_try \/etc\/dovecot\/protocols\.d/g' /etc/dovecot/dovecot.conf
RUN cp -a /etc/ssl/dovecot/server.pem /etc/dovecot/dovecot.pem
RUN mkdir /etc/dovecot/private && cp -a /etc/ssl/dovecot/server.pem /etc/dovecot/private/dovecot.pem
ADD target/dovecot/auth-passwdfile.inc /etc/dovecot/conf.d/
ADD target/dovecot/10-*.conf /etc/dovecot/conf.d/

# Enables Spamassassin and CRON updates
RUN sed -i -r 's/^(CRON|ENABLED)=0/\1=1/g' /etc/conf.d/spamd


#################################
# Haven't had time to look into amavis. I know to add uses you need the `shadow` package which is in the edge repo.
#################################

# Enables Amavis
#RUN sed -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode
#RUN adduser clamav amavis
#RUN adduser amavis clamav
# Trying to make dovecot start
RUN groupadd docker
RUN useradd -u 5000 -d /home/docker -s /bin/bash -p $(echo docker | openssl passwd -1 -stdin) docker

# Configure Fail2ban
ADD target/fail2ban/jail.conf /etc/fail2ban/jail.conf
ADD target/fail2ban/filters.d/dovecot.conf /etc/fail2ban/filters.d/dovecot.conf
RUN echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf

# Enables Clamav
RUN cp /etc/clamav/freshclam.conf.sample /etc/clamav/freshclam.conf
RUN cp /etc/clamav/clamd.conf.sample /etc/clamav/clamd.conf
RUN chmod 644 /etc/clamav/freshclam.conf
RUN (crontab -l; echo "0 1 * * * /usr/bin/freshclam --quiet") | sort - | uniq - | crontab -
#################################
# Updates are working. Builds are much faster if we disable the updates though.
#RUN freshclam
#################################

## Configure DKIM (opendkim)
#RUN mkdir -p /etc/opendkim/keys
#ADD target/opendkim/TrustedHosts /etc/opendkim/TrustedHosts
## DKIM config files
#ADD target/opendkim/opendkim.conf /etc/opendkim.conf
#ADD target/opendkim/default-opendkim /etc/default/opendkim

# Configure DMARC (opendmarc)
ADD target/opendmarc/opendmarc.conf /etc/opendmarc.conf
ADD target/opendmarc/default-opendmarc /etc/default/opendmarc

# Configures Postfix
ADD target/postfix/main.cf /etc/postfix/main.cf
ADD target/postfix/master.cf /etc/postfix/master.cf
ADD target/bin/generate-ssl-certificate /usr/local/bin/generate-ssl-certificate
RUN chmod +x /usr/local/bin/generate-ssl-certificate

# Configuring Logs
RUN sed -i -r "/^#?compress/c\compress\ncopytruncate" /etc/logrotate.conf
# rsyslog runs as root under alpine
RUN mkdir -p /var/log/mail && chown root:root /var/log/mail
RUN touch /var/log/mail/clamav.log && chown -R clamav:root /var/log/mail/clamav.log
RUN touch /var/log/mail/freshclam.log &&  chown -R clamav:root /var/log/mail/freshclam.log
RUN sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/rsyslog.conf
RUN sed -i -r 's|LogFile /var/log/clamav/|LogFile /var/log/mail/|g' /etc/clamav/clamd.conf
RUN sed -i -r 's|UpdateLogFile /var/log/clamav/|UpdateLogFile /var/log/mail/|g' /etc/clamav/freshclam.conf
RUN sed -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamd
RUN sed -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/freshclam
RUN sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/logrotate.d/rsyslog

# Get LetsEncrypt signed certificate
RUN curl -s https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x1-cross-signed.pem
RUN curl -s https://letsencrypt.org/certs/lets-encrypt-x2-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x2-cross-signed.pem

# Start-mailserver script
ADD target/start-mailserver.sh /usr/local/bin/start-mailserver.sh
RUN chmod +x /usr/local/bin/start-mailserver.sh

# SMTP ports
EXPOSE 25 587

# IMAP ports
EXPOSE 143 993

# POP3 ports
EXPOSE 110 995

CMD /usr/local/bin/start-mailserver.sh
