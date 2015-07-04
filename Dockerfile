FROM ubuntu:14.04
MAINTAINER Thomas VIAL

# Packages
RUN apt-get update -q
RUN apt-get -y upgrade
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install vim postfix sasl2-bin courier-imap courier-imap-ssl courier-authdaemon supervisor libfam0 fam amavisd-new spamassassin clamav-daemon libnet-dns-perl libmail-spf-perl pyzor razor arj bzip2 cabextract cpio file gzip nomarch pax unzip zip zoo rsyslog
RUN apt-get autoclean

# Configures Saslauthd
RUN rm -rf /var/run/saslauthd && ln -s /var/spool/postfix/var/run/saslauthd /var/run/saslauthd
RUN adduser postfix sasl
RUN echo 'NAME="saslauthd"\nSTART=yes\nMECHANISMS="sasldb"\nTHREADS=0\nPWDIR=/var/spool/postfix/var/run/saslauthd\nPIDFILE="${PWDIR}/saslauthd.pid"\nOPTIONS="-n 0 -r -m /var/spool/postfix/var/run/saslauthd"' > /etc/default/saslauthd

# Configures Courier
RUN sed -i -r 's/daemons=5/daemons=0/g' /etc/courier/authdaemonrc
RUN sed -i -r 's/authmodulelist="authpam"/authmodulelist="authuserdb"/g' /etc/courier/authdaemonrc

# Enables Spamassassin and CRON updates
RUN sed -i -r 's/^(CRON|ENABLED)=0/\1=1/g' /etc/default/spamassassin

# Enables Amavis
RUN sed -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode
RUN adduser clamav amavis
RUN adduser amavis clamav

# Enables Clamav
RUN chmod 644 /etc/clamav/freshclam.conf
RUN (crontab -l ; echo "0 1 * * * /usr/bin/freshclam --quiet") | sort - | uniq - | crontab -
RUN freshclam

# Configures Postfix
ADD postfix/main.cf /etc/postfix/main.cf
ADD postfix/master.cf /etc/postfix/master.cf
ADD postfix/sasl/smtpd.conf /etc/postfix/sasl/smtpd.conf

# Start-mailserver script
ADD start-mailserver.sh /usr/local/bin/start-mailserver.sh
RUN chmod +x /usr/local/bin/start-mailserver.sh
CMD /usr/local/bin/start-mailserver.sh

