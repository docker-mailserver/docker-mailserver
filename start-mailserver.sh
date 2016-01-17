#!/bin/sh

die () {
  echo >&2 "$@"
  exit 1
}

if [ -f /tmp/postfix/accounts.cf ]; then
  echo "Regenerating postfix 'vmailbox' and 'virtual' for given users"
  echo "# WARNING: this file is auto-generated. Modify accounts.cf in postfix directory on host" > /etc/postfix/vmailbox

  # Checking that /tmp/postfix/accounts.cf ends with a newline
  sed -i -e '$a\' /tmp/postfix/accounts.cf

  # Creating users
  while IFS=$'|' read login pass
  do
    # Setting variables for better readability
    user=$(echo ${login} | cut -d @ -f1)
    domain=$(echo ${login} | cut -d @ -f2)
    # Let's go!
    echo "user '${user}' for domain '${domain}' with password '********'"
    echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
    /usr/sbin/userdb ${login} set uid=5000 gid=5000 home=/var/mail/${domain}/${user} mail=/var/mail/${domain}/${user}
    echo "${pass}" | userdbpw -md5 | userdb ${login} set systempw
    echo "${pass}" | saslpasswd2 -p -c -u ${domain} ${login}
    mkdir -p /var/mail/${domain}
    if [ ! -d "/var/mail/${domain}/${user}" ]; then
      maildirmake "/var/mail/${domain}/${user}"
    fi
    echo ${domain} >> /tmp/vhost.tmp
  done < /tmp/postfix/accounts.cf
  makeuserdb
else
  echo "==> Warning: '/tmp/postfix/accounts.cf' is not provided. No mail account created."
fi

if [ -f /tmp/postfix/virtual ]; then
  # Copying virtual file
  cp /tmp/postfix/virtual /etc/postfix/virtual
  while IFS=$' ' read from to
  do
    # Setting variables for better readability
    domain=$(echo ${from} | cut -d @ -f2)
    echo ${domain} >> /tmp/vhost.tmp
  done < /tmp/postfix/virtual
else
  echo "==> Warning: '/tmp/postfix/virtual' is not provided. No mail alias created."
fi

if [ -f /tmp/vhost.tmp ]; then
  cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
fi

echo "Postfix configurations"
touch /etc/postfix/vmailbox && postmap /etc/postfix/vmailbox
touch /etc/postfix/virtual && postmap /etc/postfix/virtual

# SSL Configuration
case $DMS_SSL in
  "letsencrypt" )
    # letsencrypt folders and files mounted in /etc/letsencrypt

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/letsencrypt\/live\/'$(hostname)'\/fullchain.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/letsencrypt\/live\/'$(hostname)'\/privkey.pem/g' /etc/postfix/main.cf

      # Courier configuration
      cat /etc/letsencrypt/live/$(hostname)/privkey.pem /etc/letsencrypt/live/$(hostname)/cert.pem > /etc/letsencrypt/live/$(hostname)/combined.pem
      sed -i -r 's/TLS_CERTFILE=\/etc\/courier\/imapd.pem/TLS_CERTFILE=\/etc\/letsencrypt\/live\/'$(hostname)'\/combined.pem/g' /etc/courier/imapd-ssl

      echo "SSL configured with letsencrypt certificates"

    ;;

  "self-signed" )
    # Adding self-signed SSL certificate if provided in 'postfix/ssl' folder
    if [ -e "/tmp/postfix/ssl/$(hostname)-cert.pem" ] \
    && [ -e "/tmp/postfix/ssl/$(hostname)-key.pem"  ] \
    && [ -e "/tmp/postfix/ssl/$(hostname)-combined.pem" ] \
    && [ -e "/tmp/postfix/ssl/demoCA/cacert.pem" ]; then
      echo "Adding $(hostname) SSL certificate"
      mkdir -p /etc/postfix/ssl
      cp /tmp/postfix/ssl/$(hostname)-cert.pem /etc/postfix/ssl
      cp /tmp/postfix/ssl/$(hostname)-key.pem /etc/postfix/ssl
      cp /tmp/postfix/ssl/$(hostname)-combined.pem /etc/postfix/ssl
      cp /tmp/postfix/ssl/demoCA/cacert.pem /etc/postfix/ssl

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/postfix\/ssl\/'$(hostname)'-cert.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/postfix\/ssl\/'$(hostname)'-key.pem/g' /etc/postfix/main.cf
      sed -i -r 's/#smtpd_tls_CAfile=/smtpd_tls_CAfile=\/etc\/postfix\/ssl\/cacert.pem/g' /etc/postfix/main.cf
      sed -i -r 's/#smtp_tls_CAfile=/smtp_tls_CAfile=\/etc\/postfix\/ssl\/cacert.pem/g' /etc/postfix/main.cf
      ln -s /etc/postfix/ssl/cacert.pem /etc/ssl/certs/cacert-$(hostname).pem

      # Courier configuration
      sed -i -r 's/TLS_CERTFILE=\/etc\/courier\/imapd.pem/TLS_CERTFILE=\/etc\/postfix\/ssl\/'$(hostname)'-combined.pem/g' /etc/courier/imapd-ssl
    fi

    ;;

esac

echo "Fixing permissions"
chown -R 5000:5000 /var/mail
mkdir -p /var/log/clamav && chown -R clamav:root /var/log/clamav
chown postfix.sasl /etc/sasldb2

echo "Creating /etc/mailname"
echo $(hostname -d) > /etc/mailname

echo "Configuring Spamassassin"
echo "required_hits 5.0" >> /etc/mail/spamassassin/local.cf
echo "report_safe 0" >> /etc/mail/spamassassin/local.cf
echo "required_score 5" >> /etc/mail/spamassassin/local.cf
echo "rewrite_header Subject ***SPAM***" >> /etc/mail/spamassassin/local.cf
cp /tmp/spamassassin/rules.cf /etc/spamassassin/

echo "Starting daemons"
cron
/etc/init.d/rsyslog start
/etc/init.d/saslauthd start
/etc/init.d/courier-authdaemon start
/etc/init.d/courier-imap start
/etc/init.d/courier-imap-ssl start
/etc/init.d/spamassassin start
/etc/init.d/clamav-daemon start
/etc/init.d/amavis start
/etc/init.d/postfix start

echo "Listing SASL users"
sasldblistusers2

echo "Starting..."
tail -f /var/log/mail.log
