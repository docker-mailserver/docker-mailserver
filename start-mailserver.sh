#!/bin/bash

die () {
  echo >&2 "$@"
  exit 1
}

mkpaths () {
  test ! -z "$1" && domain=$1 || die "mkpaths: no domain provided... Exiting"
  test ! -z "$2" && user=$2 || die "mkpaths: no user provided... Exiting"

  mkdir -p /var/mail/${domain}
  if [ ! -d "/var/mail/${domain}/${user}" ]; then
    maildirmake "/var/mail/${domain}/${user}"
    maildirmake "/var/mail/${domain}/${user}/.Sent"
    maildirmake "/var/mail/${domain}/${user}/.Trash"
    maildirmake "/var/mail/${domain}/${user}/.Drafts"
    echo -e "INBOX\nINBOX.Sent\nINBOX.Trash\nInbox.Drafts" >> "/var/mail/${domain}/${user}/courierimapsubscribed"
    touch "/var/mail/${domain}/${user}/.Sent/maildirfolder"
  fi
  echo ${domain} >> /tmp/vhost.tmp
}

if [ -f /tmp/postfix/accounts-db/userdb -a -f /tmp/postfix/accounts-db/sasldb2 ]; then
  CDB="/etc/courier/userdb"
  SASLDB="/etc/sasldb2"
  # User databases have been already prepared
  echo "Found user databases already setup"
  cp /tmp/postfix/accounts-db/userdb ${CDB}
  chown root:root ${CDB}
  chmod 600 ${CDB}
  cp /tmp/postfix/accounts-db/sasldb2 ${SASLDB}
  chown postfix:sasl ${SASLDB}
  chmod 660 ${SASLDB}
  echo "Regenerating postfix 'vmailbox' and 'virtual' for given users"
  echo "# WARNING: this file is auto-generated. Modify accounts.cf in postfix directory on host" > /etc/postfix/vmailbox
  # Create the expected maildir paths
  awk '{u=substr($1,1,index($1,"@")-1); d=substr($1,index($1,"@")+1,length($1)); print u" "d}' ${CDB} | \
    while read user domain; do
      mkpaths ${domain} ${user}
      echo "${user}@${domain} ${domain}/${user}/" >> /etc/postfix/vmailbox
    done
  makeuserdb
else 
  # should exit with explicit message!
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
      # Create the expected maildir paths
      mkpaths ${domain} ${user}
    done < /tmp/postfix/accounts.cf
    makeuserdb
  else
      echo "==> Accounts: '/tmp/postfix/userdb' and '/tmp/postfix/sasldb2' OR '/tmp/postfix/accounts.cf' "
      echo "==>  Warning: None of those files are provided. No mail account created."
  fi
fi

if [ -f /tmp/postfix/virtual ]; then
  # Copying virtual file
  cp /tmp/postfix/virtual /etc/postfix/virtual
  while read from to
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

# manual mailbox configuration (reference http://www.postfix.org/VIRTUAL_README.html#virtual_mailbox)
cat /tmp/postfix/vmailbox >> /etc/postfix/vmailbox

echo "Postfix configurations"
touch /etc/postfix/vmailbox && postmap /etc/postfix/vmailbox
touch /etc/postfix/virtual && postmap /etc/postfix/virtual

# DKIM
grep -vE '^(\s*$|#)' /etc/postfix/vhost | while read domainname; do
  mkdir -p /etc/opendkim/keys/$domainname
  if [ ! -f "/etc/opendkim/keys/$domainname/mail.private" ]; then
    echo "Creating DKIM private key /etc/opendkim/keys/$domainname/mail.private"
    pushd /etc/opendkim/keys/$domainname
    opendkim-genkey --subdomains --domain=$domainname --selector=mail
    popd
    echo ""
    echo "DKIM PUBLIC KEY ################################################################"
    cat /etc/opendkim/keys/$domainname/mail.txt
    echo "################################################################################"
  fi
  # Write to KeyTable if necessary
  keytableentry="mail._domainkey.$domainname $domainname:mail:/etc/opendkim/keys/$domainname/mail.private"
  if [ ! -f "/etc/opendkim/KeyTable" ]; then
    echo "Creating DKIM KeyTable"
    echo "mail._domainkey.$domainname $domainname:mail:/etc/opendkim/keys/$domainname/mail.private" > /etc/opendkim/KeyTable
  else
    if ! grep -q "$keytableentry" "/etc/opendkim/KeyTable" ; then
      echo $keytableentry >> /etc/opendkim/KeyTable
    fi
  fi
  # Write to SigningTable if necessary
  signingtableentry="*@$domainname mail._domainkey.$domainname"
  if [ ! -f "/etc/opendkim/SigningTable" ]; then
    echo "Creating DKIM SigningTable"
    echo "*@$domainname mail._domainkey.$domainname" > /etc/opendkim/SigningTable
  else
    if ! grep -q "$signingtableentry" "/etc/opendkim/SigningTable" ; then
      echo $signingtableentry >> /etc/opendkim/SigningTable
    fi
  fi
done

echo "Changing permissions on /etc/opendkim"
# chown entire directory
chown -R opendkim:opendkim /etc/opendkim/
# And make sure permissions are right
chmod -R 0700 /etc/opendkim/keys/

# DMARC
# if ther is no AuthservID create it
if [ `cat /etc/opendmarc.conf | grep -w AuthservID | wc -l` -eq 0 ]; then
  echo "AuthservID $(hostname)" >> /etc/opendmarc.conf
fi
if [ `cat /etc/opendmarc.conf | grep -w TrustedAuthservIDs | wc -l` -eq 0 ]; then
  echo "TrustedAuthservIDs $(hostname)" >> /etc/opendmarc.conf
fi
if [ ! -f "/etc/opendmarc/ignore.hosts" ]; then
  mkdir -p /etc/opendmarc/
  echo "localhost" >> /etc/opendmarc/ignore.hosts
fi

# SSL Configuration
case $DMS_SSL in
  "letsencrypt" )
    # letsencrypt folders and files mounted in /etc/letsencrypt
    if [ -e "/etc/letsencrypt/live/$(hostname)/cert.pem" ] \
    && [ -e "/etc/letsencrypt/live/$(hostname)/chain.pem" ] \
    && [ -e "/etc/letsencrypt/live/$(hostname)/privkey.pem" ]; then
      echo "Adding $(hostname) SSL certificate"
      # create combined.pem from (cert|chain|privkey).pem with eol after each .pem
      sed -e '$a\' -s /etc/letsencrypt/live/$(hostname)/{cert,chain,privkey}.pem > /etc/letsencrypt/live/$(hostname)/combined.pem

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/letsencrypt\/live\/'$(hostname)'\/fullchain.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/letsencrypt\/live\/'$(hostname)'\/privkey.pem/g' /etc/postfix/main.cf

      # Courier configuration
      sed -i -r 's/TLS_CERTFILE=\/etc\/courier\/imapd.pem/TLS_CERTFILE=\/etc\/letsencrypt\/live\/'$(hostname)'\/combined.pem/g' /etc/courier/imapd-ssl

      # POP3 courier configuration
      sed -i -r 's/POP3_TLS_REQUIRED=0/POP3_TLS_REQUIRED=1/g' /etc/courier/pop3d-ssl
      sed -i -r 's/TLS_CERTFILE=\/etc\/courier\/pop3d.pem/TLS_CERTFILE=\/etc\/letsencrypt\/live\/'$(hostname)'\/combined.pem/g' /etc/courier/pop3d-ssl
      # needed to support gmail
      sed -i -r 's/TLS_TRUSTCERTS=\/etc\/ssl\/certs/TLS_TRUSTCERTS=\/etc\/letsencrypt\/live\/'$(hostname)'\/fullchain.pem/g' /etc/courier/pop3d-ssl

      echo "SSL configured with letsencrypt certificates"

    fi
    ;;

  "custom" )
    # Adding CA signed SSL certificate if provided in 'postfix/ssl' folder
    if [ -e "/tmp/postfix/ssl/$(hostname)-full.pem" ]; then
      echo "Adding $(hostname) SSL certificate"
      mkdir -p /etc/postfix/ssl
      cp "/tmp/postfix/ssl/$(hostname)-full.pem" /etc/postfix/ssl

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/postfix\/ssl\/'$(hostname)'-full.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/postfix\/ssl\/'$(hostname)'-full.pem/g' /etc/postfix/main.cf

      # Courier configuration
      sed -i -r 's/TLS_CERTFILE=\/etc\/courier\/imapd.pem/TLS_CERTFILE=\/etc\/postfix\/ssl\/'$(hostname)'-full.pem/g' /etc/courier/imapd-ssl

      # POP3 courier configuration
      sed -i -r 's/POP3_TLS_REQUIRED=0/POP3_TLS_REQUIRED=1/g' /etc/courier/pop3d-ssl
      sed -i -r 's/TLS_CERTFILE=\/etc\/courier\/pop3d.pem/TLS_CERTFILE=\/etc\/postfix\/ssl\/'$(hostname)'-full.pem/g' /etc/courier/pop3d-ssl

      echo "SSL configured with CA signed/custom certificates"

    fi
    ;;

  "self-signed" )
    # Adding self-signed SSL certificate if provided in 'postfix/ssl' folder
    if [ -e "/tmp/postfix/ssl/$(hostname)-cert.pem" ] \
    && [ -e "/tmp/postfix/ssl/$(hostname)-key.pem"  ] \
    && [ -e "/tmp/postfix/ssl/$(hostname)-combined.pem" ] \
    && [ -e "/tmp/postfix/ssl/demoCA/cacert.pem" ]; then
      echo "Adding $(hostname) SSL certificate"
      mkdir -p /etc/postfix/ssl
      cp "/tmp/postfix/ssl/$(hostname)-cert.pem" /etc/postfix/ssl
      cp "/tmp/postfix/ssl/$(hostname)-key.pem" /etc/postfix/ssl
      cp "/tmp/postfix/ssl/$(hostname)-combined.pem" /etc/postfix/ssl
      cp /tmp/postfix/ssl/demoCA/cacert.pem /etc/postfix/ssl

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/postfix\/ssl\/'$(hostname)'-cert.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/postfix\/ssl\/'$(hostname)'-key.pem/g' /etc/postfix/main.cf
      sed -i -r 's/#smtpd_tls_CAfile=/smtpd_tls_CAfile=\/etc\/postfix\/ssl\/cacert.pem/g' /etc/postfix/main.cf
      sed -i -r 's/#smtp_tls_CAfile=/smtp_tls_CAfile=\/etc\/postfix\/ssl\/cacert.pem/g' /etc/postfix/main.cf
      ln -s /etc/postfix/ssl/cacert.pem "/etc/ssl/certs/cacert-$(hostname).pem"

      # Courier configuration
      sed -i -r 's/TLS_CERTFILE=\/etc\/courier\/imapd.pem/TLS_CERTFILE=\/etc\/postfix\/ssl\/'$(hostname)'-combined.pem/g' /etc/courier/imapd-ssl

      # POP3 courier configuration
      sed -i -r 's/POP3_TLS_REQUIRED=0/POP3_TLS_REQUIRED=1/g' /etc/courier/pop3d-ssl
      sed -i -r 's/TLS_CERTFILE=\/etc\/courier\/pop3d.pem/TLS_CERTFILE=\/etc\/postfix\/ssl\/'$(hostname)'-combined.pem/g' /etc/courier/pop3d-ssl

      echo "SSL configured with self-signed/custom certificates"

    fi
    ;;

esac

if [ -f /tmp/postfix/main.cf ]; then
  while read line; do
    postconf -e "$line"
  done < /tmp/postfix/main.cf
  echo "Loaded '/tmp/postfix/main.cf'"
else
  echo "'/tmp/postfix/main.cf' not provided. No extra postfix settings loaded."
fi

if [ ! -z "$SASL_PASSWORD" ]; then
  echo "$SASL_PASSWORD" > /etc/postfix/sasl_passwd
  postmap hash:/etc/postfix/sasl_passwd
  rm /etc/postfix/sasl_passwd
  chown root:root /etc/postfix/sasl_passwd.db
  chmod 0600 /etc/postfix/sasl_passwd.db
  echo "Loaded SASL_PASSWORD"
else
  echo "Info: SASL_PASSWORD is not provided. /etc/postfix/sasl_passwd not created."
fi

echo "Fixing permissions"
chown -R 5000:5000 /var/mail
chown postfix.sasl /etc/sasldb2

echo "Creating /etc/mailname"
echo $(hostname -d) > /etc/mailname

echo "Configuring Spamassassin"
SA_TAG=${SA_TAG:="2.0"} && sed -i -r 's/^\$sa_tag_level_deflt (.*);/\$sa_tag_level_deflt = '$SA_TAG';/g' /etc/amavis/conf.d/20-debian_defaults
SA_TAG2=${SA_TAG2:="6.31"} && sed -i -r 's/^\$sa_tag2_level_deflt (.*);/\$sa_tag2_level_deflt = '$SA_TAG2';/g' /etc/amavis/conf.d/20-debian_defaults
SA_KILL=${SA_KILL:="6.31"} && sed -i -r 's/^\$sa_kill_level_deflt (.*);/\$sa_kill_level_deflt = '$SA_KILL';/g' /etc/amavis/conf.d/20-debian_defaults
test -e /tmp/spamassassin/rules.cf && cp /tmp/spamassassin/rules.cf /etc/spamassassin/

echo "Configuring fail2ban"
# enable filters
awk 'BEGIN{unit=0}{if ($1=="[postfix]" || $1=="[couriersmtp]" || $1=="[courierauth]" || $1=="[sasl]") {unit=1;}
      if ($1=="enabled" && unit==1) $3="true";
       else if ($1=="logpath" && unit==1) $3="/var/log/mail/mail.log";
      print;
      if (unit==1 && $1~/\[/ && $1!~/postfix|couriersmtp|courierauth|sasl/) unit=0;
}' /etc/fail2ban/jail.conf > /tmp/jail.conf.new && mv /tmp/jail.conf.new /etc/fail2ban/jail.conf && rm -f /tmp/jail.conf.new

# increase ban time and find time to 3h
sed -i "/^bantime *=/c\bantime = 10800"     /etc/fail2ban/jail.conf
sed -i "/^findtime *=/c\findtime = 10800"   /etc/fail2ban/jail.conf

# avoid warning on startup
echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf

# continue to write the log information in the newly created file after rotating the old log file
sed -i -r "/^#?compress/c\compress\ncopytruncate" /etc/logrotate.conf

# Setup logging
mkdir -p /var/log/mail && chown syslog:root /var/log/mail
touch /var/log/mail/clamav.log && chown -R clamav:root /var/log/mail/clamav.log
touch /var/log/mail/freshclam.log &&  chown -R clamav:root /var/log/mail/freshclam.log
sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/rsyslog.d/50-default.conf
sed -i -r 's|LogFile /var/log/clamav/|LogFile /var/log/mail/|g' /etc/clamav/clamd.conf
sed -i -r 's|UpdateLogFile /var/log/clamav/|UpdateLogFile /var/log/mail/|g' /etc/clamav/freshclam.conf
sed -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-daemon
sed -i -r 's|/var/log/clamav|/var/log/mail|g' /etc/logrotate.d/clamav-freshclam
sed -i -r 's|/var/log/mail|/var/log/mail/mail|g' /etc/logrotate.d/rsyslog

echo "Starting daemons"
cron
/etc/init.d/rsyslog start
/etc/init.d/saslauthd start

if [ "$SMTP_ONLY" != 1 ]; then

/etc/init.d/courier-authdaemon start
/etc/init.d/courier-imap start
/etc/init.d/courier-imap-ssl start

fi
if [ "$ENABLE_POP3" = 1 -a "$SMTP_ONLY" != 1 ]; then
  echo "Starting POP3 services"
  /etc/init.d/courier-pop start
  /etc/init.d/courier-pop-ssl start
fi

/etc/init.d/spamassassin start
/etc/init.d/clamav-daemon start
/etc/init.d/amavis start
/etc/init.d/opendkim start
/etc/init.d/opendmarc start
/etc/init.d/postfix start

if [ "$ENABLE_FAIL2BAN" = 1 ]; then
  echo "Starting fail2ban service"
  /etc/init.d/fail2ban start
fi

echo "Listing SASL users"
sasldblistusers2

echo "Starting..."
tail -f /var/log/mail/mail.log
