FROM ubuntu:14.04
MAINTAINER Thomas VIAL


ENV DEBIAN_FRONTEND noninteractive



# Packages
RUN apt-get update && \
  apt-get upgrade -y --no-install-recommends && \
  apt-get install -y --no-install-recommends \
    postfix sasl2-bin libsasl2-modules courier-imap courier-imap-ssl \
    courier-pop courier-pop-ssl courier-authdaemon supervisor gamin amavisd-new spamassassin clamav clamav-daemon libnet-dns-perl libmail-spf-perl \
    pyzor razor arj bzip2 cabextract cpio file gzip nomarch p7zip pax unzip zip zoo rsyslog mailutils netcat \
    opendkim opendkim-tools opendmarc curl fail2ban



# Copy configuration files/executables
COPY /target /



# Configures Saslauthd
RUN rm -rf /var/run/saslauthd && ln -s /var/spool/postfix/var/run/saslauthd /var/run/saslauthd && \
  adduser postfix sasl && \
  echo 'NAME="saslauthd"\nSTART=yes\nMECHANISMS="sasldb"\nTHREADS=0\nPWDIR=/var/spool/postfix/var/run/saslauthd\nPIDFILE="${PWDIR}/saslauthd.pid"\nOPTIONS="-n 0 -c -m /var/spool/postfix/var/run/saslauthd"' > /etc/default/saslauthd && \
  \
  # Configures Courier \
  sed -i -r 's/daemons=5/daemons=1/g' /etc/courier/authdaemonrc && \
  sed -i -r 's/authmodulelist="authpam"/authmodulelist="authuserdb"/g' /etc/courier/authdaemonrc && \
  \
  # Enables Spamassassin and CRON updates \
  sed -i -r 's/^(CRON|ENABLED)=0/\1=1/g' /etc/default/spamassassin && \
  \
  # Enables Amavis \
  sed -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode && \
  adduser clamav amavis && \
  adduser amavis clamav && \
  useradd -u 5000 -d /home/docker -s /bin/bash -p $(echo docker | openssl passwd -1 -stdin) docker && \
  \
  # Enables Clamav \
  chmod 644 /etc/clamav/freshclam.conf && \
  (crontab -l ; echo "0 1 * * * /usr/bin/freshclam --quiet") | sort - | uniq - | crontab - && \
  freshclam && \
  \
  # Configure DKIM (opendkim) \
  mkdir -p /etc/opendkim/keys && \
  chmod +x /usr/local/bin/generate-ssl-certificate && \
  \
  # Get LetsEncrypt signed certificate \
  curl https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x1-cross-signed.pem && \
  curl https://letsencrypt.org/certs/lets-encrypt-x2-cross-signed.pem > /etc/ssl/certs/lets-encrypt-x2-cross-signed.pem && \
  \
  # Start-mailserver script \
  chmod +x /usr/local/bin/start-mailserver.sh && \
  \
  # Cleanup
  apt-get clean && \
  rm -rf /tmp/* /var/tmp/* && \
  rm -rf /var/lib/apt/lists/*



#      SMTP   | IMAP    | POP3
EXPOSE 25 587   143 993   110 995



CMD /usr/local/bin/start-mailserver.sh
