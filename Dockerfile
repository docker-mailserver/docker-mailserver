FROM ubuntu:14.04
MAINTAINER Thomas VIAL

# Packages
RUN apt-get update -q --fix-missing
RUN apt-get -y upgrade
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install vim postfix dovecot-core dovecot-imapd dovecot-pop3d \
    supervisor gamin amavisd-new spamassassin clamav clamav-daemon libnet-dns-perl libmail-spf-perl \
    pyzor razor arj bzip2 cabextract cpio file gzip nomarch p7zip pax unzip zip zoo rsyslog mailutils netcat \
    opendkim opendkim-tools opendmarc curl fail2ban sasl2-bin
RUN apt-get autoclean && rm -rf /var/lib/apt/lists/*

# Configures Dovecot
RUN sed -i -e 's/include_try \/usr\/share\/dovecot\/protocols\.d/include_try \/etc\/dovecot\/protocols\.d/g' /etc/dovecot/dovecot.conf
ADD target/dovecot/auth-passwdfile.inc /etc/dovecot/conf.d/
ADD target/dovecot/10-*.conf /etc/dovecot/conf.d/

# Enables Spamassassin and CRON updates
RUN sed -i -r 's/^(CRON|ENABLED)=0/\1=1/g' /etc/default/spamassassin

# Enables Amavis
RUN sed -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode
RUN adduser clamav amavis
RUN adduser amavis clamav
RUN useradd -u 5000 -d /home/docker -s /bin/bash -p $(echo docker | openssl passwd -1 -stdin) docker

# Enables Clamav
RUN chmod 644 /etc/clamav/freshclam.conf
RUN (crontab -l ; echo "0 1 * * * /usr/bin/freshclam --quiet") | sort - | uniq - | crontab -
RUN freshclam

# Configure DKIM (opendkim)
RUN mkdir -p /etc/opendkim/keys
ADD target/opendkim/TrustedHosts /etc/opendkim/TrustedHosts
# DKIM config files
ADD target/opendkim/opendkim.conf /etc/opendkim.conf
ADD target/opendkim/default-opendkim /etc/default/opendkim

# Configure DMARC (opendmarc)
ADD target/opendmarc/opendmarc.conf /etc/opendmarc.conf
ADD target/opendmarc/default-opendmarc /etc/default/opendmarc

# Configures Postfix
ADD target/postfix/main.cf /etc/postfix/main.cf
ADD target/postfix/master.cf /etc/postfix/master.cf
ADD target/bin/generate-ssl-certificate /usr/local/bin/generate-ssl-certificate
RUN chmod +x /usr/local/bin/generate-ssl-certificate

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
