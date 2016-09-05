#!/bin/bash

die () {
  echo >&2 "$@"
  exit 1
}

#
# Users
#
if [ -f /tmp/docker-mailserver/postfix-accounts.cf ]; then
  echo "Checking file line endings"
  sed -i 's/\r//g' /tmp/docker-mailserver/postfix-accounts.cf
  echo "Regenerating postfix 'vmailbox' and 'virtual' for given users"
  echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox

  # Checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
  sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf
  # Configuring Dovecot
  echo -n > /etc/dovecot/userdb
  chown dovecot:dovecot /etc/dovecot/userdb
  chmod 640 /etc/dovecot/userdb
  cp -a /usr/share/dovecot/protocols.d /etc/dovecot/
  # Disable pop3 (it will be eventually enabled later in the script, if requested)
  mv /etc/dovecot/protocols.d/pop3d.protocol /etc/dovecot/protocols.d/pop3d.protocol.disab
  mv /etc/dovecot/protocols.d/managesieved.protocol /etc/dovecot/protocols.d/managesieved.protocol.disab
  sed -i -e 's/#ssl = yes/ssl = yes/g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's/#port = 993/port = 993/g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's/#port = 995/port = 995/g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's/#ssl = yes/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf

  # Creating users
  # 'pass' is encrypted
  while IFS=$'|' read login pass
  do
    # Setting variables for better readability
    user=$(echo ${login} | cut -d @ -f1)
    domain=$(echo ${login} | cut -d @ -f2)
    # Let's go!
    echo "user '${user}' for domain '${domain}' with password '********'"
    echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
    # User database for dovecot has the following format:
    # user:password:uid:gid:(gecos):home:(shell):extra_fields
    # Example :
    # ${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::userdb_mail=maildir:/var/mail/${domain}/${user}
    echo "${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::" >> /etc/dovecot/userdb
    mkdir -p /var/mail/${domain}
    if [ ! -d "/var/mail/${domain}/${user}" ]; then
      maildirmake.dovecot "/var/mail/${domain}/${user}"
      maildirmake.dovecot "/var/mail/${domain}/${user}/.Sent"
      maildirmake.dovecot "/var/mail/${domain}/${user}/.Trash"
      maildirmake.dovecot "/var/mail/${domain}/${user}/.Drafts"
      echo -e "INBOX\nSent\nTrash\nDrafts" >> "/var/mail/${domain}/${user}/subscriptions"
      touch "/var/mail/${domain}/${user}/.Sent/maildirfolder"
    fi
    # Copy user provided sieve file, if present
    test -e /tmp/docker-mailserver/${login}.dovecot.sieve && cp /tmp/docker-mailserver/${login}.dovecot.sieve /var/mail/${domain}/${user}/.dovecot.sieve
    echo ${domain} >> /tmp/vhost.tmp
  done < /tmp/docker-mailserver/postfix-accounts.cf
else
  echo "==> Warning: 'config/docker-mailserver/postfix-accounts.cf' is not provided. No mail account created."
fi

#
# Aliases
#
if [ -f /tmp/docker-mailserver/postfix-virtual.cf ]; then
  # Copying virtual file
  cp /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual
  while read from to
  do
    # Setting variables for better readability
    uname=$(echo ${from} | cut -d @ -f1)
    domain=$(echo ${from} | cut -d @ -f2)
    # if they are equal it means the line looks like: "user1     other@domain.tld"
    test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
  done < /tmp/docker-mailserver/postfix-virtual.cf
else
  echo "==> Warning: 'config/postfix-virtual.cf' is not provided. No mail alias/forward created."
fi
if [ -f /tmp/docker-mailserver/postfix-regexp.cf ]; then
  # Copying regexp alias file
  echo "Adding regexp alias file postfix-regexp.cf"
  cp /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
  sed -i -e '/^virtual_alias_maps/{
    s/ regexp:.*//
    s/$/ regexp:\/etc\/postfix\/regexp/
    }' /etc/postfix/main.cf
fi

# DKIM
# Check if keys are already available
if [ -e "/tmp/docker-mailserver/opendkim/KeyTable" ]; then
  mkdir -p /etc/opendkim
  cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/
  echo "DKIM keys added for: `ls -C /etc/opendkim/keys/`"
  echo "Changing permissions on /etc/opendkim"
  # chown entire directory
  chown -R opendkim:opendkim /etc/opendkim/
  # And make sure permissions are right
  chmod -R 0700 /etc/opendkim/keys/
else
  echo "No DKIM key provided. Check the documentation to find how to get your keys."
fi

# DMARC
# if there is no AuthservID create it
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
case $SSL_TYPE in
  "letsencrypt" )
    # letsencrypt folders and files mounted in /etc/letsencrypt
    if [ -e "/etc/letsencrypt/live/$(hostname)/cert.pem" ] \
    && [ -e "/etc/letsencrypt/live/$(hostname)/fullchain.pem" ]; then
      KEY=""
      if [ -e "/etc/letsencrypt/live/$(hostname)/privkey.pem" ]; then
        KEY="privkey"
      elif [ -e "/etc/letsencrypt/live/$(hostname)/key.pem" ]; then
        KEY="key"
      fi
      if [ -n "$KEY" ]; then
        echo "Adding $(hostname) SSL certificate"

        # Postfix configuration
        sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/letsencrypt\/live\/'$(hostname)'\/fullchain.pem/g' /etc/postfix/main.cf
        sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/letsencrypt\/live\/'$(hostname)'\/'"$KEY"'\.pem/g' /etc/postfix/main.cf

        # Dovecot configuration
        sed -i -e 's/ssl_cert = <\/etc\/dovecot\/dovecot\.pem/ssl_cert = <\/etc\/letsencrypt\/live\/'$(hostname)'\/fullchain\.pem/g' /etc/dovecot/conf.d/10-ssl.conf
        sed -i -e 's/ssl_key = <\/etc\/dovecot\/private\/dovecot\.pem/ssl_key = <\/etc\/letsencrypt\/live\/'$(hostname)'\/'"$KEY"'\.pem/g' /etc/dovecot/conf.d/10-ssl.conf

        echo "SSL configured with 'letsencrypt' certificates"

      fi
    fi
    ;;

  "custom" )
    # Adding CA signed SSL certificate if provided in 'postfix/ssl' folder
    if [ -e "/tmp/docker-mailserver/ssl/$(hostname)-full.pem" ]; then
      echo "Adding $(hostname) SSL certificate"
      mkdir -p /etc/postfix/ssl
      cp "/tmp/docker-mailserver/ssl/$(hostname)-full.pem" /etc/postfix/ssl

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/postfix\/ssl\/'$(hostname)'-full.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/postfix\/ssl\/'$(hostname)'-full.pem/g' /etc/postfix/main.cf

      # Dovecot configuration
      sed -i -e 's/ssl_cert = <\/etc\/dovecot\/dovecot\.pem/ssl_cert = <\/etc\/postfix\/ssl\/'$(hostname)'-full\.pem/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/ssl_key = <\/etc\/dovecot\/private\/dovecot\.pem/ssl_key = <\/etc\/postfix\/ssl\/'$(hostname)'-full\.pem/g' /etc/dovecot/conf.d/10-ssl.conf

      echo "SSL configured with 'CA signed/custom' certificates"

    fi
    ;;

  "manual" )
    # Lets you manually specify the location of the SSL Certs to use. This gives you some more control over this whole processes (like using kube-lego to generate certs)
    if [ -n "$SSL_CERT_PATH" ] \
    && [ -n "$SSL_KEY_PATH" ]; then
      echo "Configuring certificates using cert $SSL_CERT_PATH and key $SSL_KEY_PATH"
      mkdir -p /etc/postfix/ssl
      cp "$SSL_CERT_PATH" /etc/postfix/ssl/cert
      cp "$SSL_KEY_PATH" /etc/postfix/ssl/key
      chmod 600 /etc/postfix/ssl/cert
      chmod 600 /etc/postfix/ssl/key

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/postfix\/ssl\/cert/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/postfix\/ssl\/key/g' /etc/postfix/main.cf

      # Dovecot configuration
      sed -i -e 's/ssl_cert = <\/etc\/dovecot\/dovecot\.pem/ssl_cert = <\/etc\/postfix\/ssl\/cert/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/ssl_key = <\/etc\/dovecot\/private\/dovecot\.pem/ssl_key = <\/etc\/postfix\/ssl\/key/g' /etc/dovecot/conf.d/10-ssl.conf

      echo "SSL configured with 'Manual' certificates"

    fi
    ;;

  "self-signed" )
    # Adding self-signed SSL certificate if provided in 'postfix/ssl' folder
    if [ -e "/tmp/docker-mailserver/ssl/$(hostname)-cert.pem" ] \
    && [ -e "/tmp/docker-mailserver/ssl/$(hostname)-key.pem"  ] \
    && [ -e "/tmp/docker-mailserver/ssl/$(hostname)-combined.pem" ] \
    && [ -e "/tmp/docker-mailserver/ssl/demoCA/cacert.pem" ]; then
      echo "Adding $(hostname) SSL certificate"
      mkdir -p /etc/postfix/ssl
      cp "/tmp/docker-mailserver/ssl/$(hostname)-cert.pem" /etc/postfix/ssl
      cp "/tmp/docker-mailserver/ssl/$(hostname)-key.pem" /etc/postfix/ssl
      # Force permission on key file
      chmod 600 /etc/postfix/ssl/$(hostname)-key.pem
      cp "/tmp/docker-mailserver/ssl/$(hostname)-combined.pem" /etc/postfix/ssl
      cp /tmp/docker-mailserver/ssl/demoCA/cacert.pem /etc/postfix/ssl

      # Postfix configuration
      sed -i -r 's/smtpd_tls_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/smtpd_tls_cert_file=\/etc\/postfix\/ssl\/'$(hostname)'-cert.pem/g' /etc/postfix/main.cf
      sed -i -r 's/smtpd_tls_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/smtpd_tls_key_file=\/etc\/postfix\/ssl\/'$(hostname)'-key.pem/g' /etc/postfix/main.cf
      sed -i -r 's/#smtpd_tls_CAfile=/smtpd_tls_CAfile=\/etc\/postfix\/ssl\/cacert.pem/g' /etc/postfix/main.cf
      sed -i -r 's/#smtp_tls_CAfile=/smtp_tls_CAfile=\/etc\/postfix\/ssl\/cacert.pem/g' /etc/postfix/main.cf
      ln -s /etc/postfix/ssl/cacert.pem "/etc/ssl/certs/cacert-$(hostname).pem"

      # Dovecot configuration
      sed -i -e 's/ssl_cert = <\/etc\/dovecot\/dovecot\.pem/ssl_cert = <\/etc\/postfix\/ssl\/'$(hostname)'-combined\.pem/g' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -e 's/ssl_key = <\/etc\/dovecot\/private\/dovecot\.pem/ssl_key = <\/etc\/postfix\/ssl\/'$(hostname)'-key\.pem/g' /etc/dovecot/conf.d/10-ssl.conf

      echo "SSL configured with 'self-signed' certificates"

    fi
    ;;

esac

if [ -f /tmp/vhost.tmp ]; then
  cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
fi

echo "Postfix configurations"
touch /etc/postfix/vmailbox && postmap /etc/postfix/vmailbox
touch /etc/postfix/virtual && postmap /etc/postfix/virtual

# PERMIT_DOCKER Option
container_ip=$(ip addr show eth0 | grep 'inet 172\.' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1)
container_network="$(echo $container_ip | cut -d '.' -f1-2).0.0"
case $PERMIT_DOCKER in
  "host" )
      echo "Adding $container_network/16 to my networks"
      postconf -e "$(postconf | grep '^mynetworks =') $container_network/16"
      bash -c "echo $container_network/16 >> /etc/opendmarc/ignore.hosts"
      bash -c "echo $container_network/16 >> /etc/opendkim/TrustedHosts"
    ;;

  "network" )
      echo "Adding docker network in my networks"
      postconf -e "$(postconf | grep '^mynetworks =') 172.16.0.0/12"
      bash -c "echo 172.16.0.0/12 >> /etc/opendmarc/ignore.hosts"
      bash -c "echo 172.16.0.0/12 >> /etc/opendkim/TrustedHosts"
    ;;

  * )
      echo "Adding container ip in my networks"
      postconf -e "$(postconf | grep '^mynetworks =') $container_ip/32"
      bash -c "echo $container_ip/32 >> /etc/opendmarc/ignore.hosts"
      bash -c "echo $container_ip/32 >> /etc/opendkim/TrustedHosts"
    ;;

esac

#
# Override Postfix configuration
#
if [ -f /tmp/docker-mailserver/postfix-main.cf ]; then
  while read line; do
    postconf -e "$line"
  done < /tmp/docker-mailserver/postfix-main.cf
  echo "Loaded 'config/postfix-main.cf'"
else
  echo "No extra postfix settings loaded because optional '/tmp/docker-mailserver/postfix-main.cf' not provided."
fi

# Support general SASL password
rm -f /etc/postfix/sasl_passwd
if [ ! -z "$SASL_PASSWD" ]; then
  echo "$SASL_PASSWD" >> /etc/postfix/sasl_passwd
fi

# Support outgoing email relay via Amazon SES
if [ ! -z "$AWS_SES_HOST" -a ! -z "$AWS_SES_USERPASS" ]; then
  if [ -z "$AWS_SES_PORT" ];then
    AWS_SES_PORT=25
  fi
  echo "Setting up outgoing email via AWS SES host $AWS_SES_HOST:$AWS_SES_PORT"
  echo "[$AWS_SES_HOST]:$AWS_SES_PORT $AWS_SES_USERPASS" >>/etc/postfix/sasl_passwd
  postconf -e \
    "relayhost = [$AWS_SES_HOST]:$AWS_SES_PORT" \
    "smtp_sasl_auth_enable = yes" \
    "smtp_sasl_security_options = noanonymous" \
    "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" \
    "smtp_use_tls = yes" \
    "smtp_tls_security_level = encrypt" \
    "smtp_tls_note_starttls_offer = yes" \
    "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
fi

# Install SASL passwords
if [ -f /etc/postfix/sasl_passwd ]; then
  postmap hash:/etc/postfix/sasl_passwd
  rm /etc/postfix/sasl_passwd
  chown root:root /etc/postfix/sasl_passwd.db
  chmod 0600 /etc/postfix/sasl_passwd.db
  echo "Loaded SASL_PASSWD"
else
  echo "==> Warning: 'SASL_PASSWD' is not provided. /etc/postfix/sasl_passwd not created."
fi

# Fix permissions, but skip this if 3 levels deep the user id is already set
if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
  echo "Fixing /var/mail permissions"
  chown -R 5000:5000 /var/mail
else
  echo "Permissions in /var/mail look OK"
fi

echo "Creating /etc/mailname"
echo $(hostname -d) > /etc/mailname

echo "Configuring Spamassassin"
SA_TAG=${SA_TAG:="2.0"} && sed -i -r 's/^\$sa_tag_level_deflt (.*);/\$sa_tag_level_deflt = '$SA_TAG';/g' /etc/amavis/conf.d/20-debian_defaults
SA_TAG2=${SA_TAG2:="6.31"} && sed -i -r 's/^\$sa_tag2_level_deflt (.*);/\$sa_tag2_level_deflt = '$SA_TAG2';/g' /etc/amavis/conf.d/20-debian_defaults
SA_KILL=${SA_KILL:="6.31"} && sed -i -r 's/^\$sa_kill_level_deflt (.*);/\$sa_kill_level_deflt = '$SA_KILL';/g' /etc/amavis/conf.d/20-debian_defaults
test -e /tmp/docker-mailserver/spamassassin-rules.cf && cp /tmp/docker-mailserver/spamassassin-rules.cf /etc/spamassassin/

if [ "$ENABLE_FAIL2BAN" = 1 ]; then
  echo "Fail2ban enabled"
  test -e /tmp/docker-mailserver/fail2ban-jail.cf && cp /tmp/docker-mailserver/fail2ban-jail.cf /etc/fail2ban/jail.local
else
  # Disable logrotate config for fail2ban if not enabled
  rm -f /etc/logrotate.d/fail2ban
fi

# Fix cron.daily for spamassassin
sed -i -e 's/invoke-rc.d spamassassin reload/\/etc\/init\.d\/spamassassin reload/g' /etc/cron.daily/spamassassin

# Consolidate all state that should be persisted across container restarts into one mounted
# directory
statedir=/var/mail-state
if [ "$ONE_DIR" = 1 -a -d $statedir ]; then
  echo "Consolidating all state onto $statedir"
  for d in /var/spool/postfix /var/lib/postfix /var/lib/amavis /var/lib/clamav /var/lib/spamassasin /var/lib/fail2ban; do
    dest=$statedir/`echo $d | sed -e 's/.var.//; s/\//-/g'`
    if [ -d $dest ]; then
      echo "  Destination $dest exists, linking $d to it"
      rm -rf $d
      ln -s $dest $d
    elif [ -d $d ]; then
      echo "  Moving contents of $d to $dest:" `ls $d`
      mv $d $dest
      ln -s $dest $d
    else
      echo "  Linking $d to $dest"
      mkdir -p $dest
      ln -s $dest $d
    fi
  done
fi

echo "Starting daemons"
cron
/etc/init.d/rsyslog start

# Enable Managesieve service by setting the symlink
# to the configuration file Dovecot will actually find
if [ "$ENABLE_MANAGESIEVE" = 1 ]; then
  echo "Sieve management enabled"
  mv /etc/dovecot/protocols.d/managesieved.protocol.disab /etc/dovecot/protocols.d/managesieved.protocol
fi

if [ "$SMTP_ONLY" != 1 ]; then
  # Here we are starting sasl and imap, not pop3 because it's disabled by default
  echo " * Starting dovecot services"
  /usr/sbin/dovecot -c /etc/dovecot/dovecot.conf
fi

if [ "$ENABLE_POP3" = 1 -a "$SMTP_ONLY" != 1 ]; then
  echo "Starting POP3 services"
  mv /etc/dovecot/protocols.d/pop3d.protocol.disab /etc/dovecot/protocols.d/pop3d.protocol
  /usr/sbin/dovecot reload
fi

if [ -f /tmp/docker-mailserver/dovecot.cf ]; then
  echo 'Adding file "dovecot.cf" to the Dovecot configuration'
  cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf
  /usr/sbin/dovecot reload
fi

# Enable fetchmail daemon
if [ "$ENABLE_FETCHMAIL" = 1 ]; then
  /usr/local/bin/setup-fetchmail
  echo "Fetchmail enabled"
  /etc/init.d/fetchmail start
fi

# Start services related to SMTP
if ! [ "$DISABLE_CLAMAV" = 1 ]; then
  /etc/init.d/clamav-daemon start
fi

# Copy user provided configuration files if provided
if [ -f /tmp/docker-mailserver/amavis.cf ]; then
  cp /tmp/docker-mailserver/amavis.cf /etc/amavis/conf.d/50-user
fi

if ! [ "$DISABLE_AMAVIS" = 1 ]; then
  /etc/init.d/amavis start
fi
/etc/init.d/opendkim start
/etc/init.d/opendmarc start
/etc/init.d/postfix start

if [ "$ENABLE_FAIL2BAN" = 1 ]; then
  echo "Starting fail2ban service"
  touch /var/log/auth.log
  /etc/init.d/fail2ban start
fi

echo "Listing users"
/usr/sbin/dovecot user '*'

echo "Starting..."
tail -f /var/log/mail/mail.log
