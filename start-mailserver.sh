#!/bin/sh

echo "Regenerating postfix 'vmailbox' and 'virtual' for given users"
# rm /etc/postfix/virtual
# rm /etc/postfix/virtual.db
# rm /etc/postfix/vmailbox
# rm /etc/postfix/vmailbox.db
echo "# WARNING: this file is auto-generated. Modify accounts.cf in postfix directory on host" > /etc/postfix/vmailbox
# Creating users
while IFS=$'|' read -r login pass
do

  # Setting variables for better readability
  user=$(echo ${login} | cut -d @ -f1)
  domain=$(echo ${login} | cut -d @ -f2)

  # Let's go!
  echo "user '${user}' for domain '${domain}' with password '********'"
  echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
  userdb ${login} set uid=5000 gid=5000 home=/var/mail/${domain}/${user} mail=/var/mail/${domain}/${user}
  echo "${pass}" | userdbpw -md5 | userdb ${login} set systempw
  echo "${pass}" | saslpasswd2 -p -c -u ${domain} ${login}
  mkdir -p /var/mail/${domain}
  maildirmake /var/mail/${domain}/${user}
  echo ${domain} >> /tmp/vhost.tmp
done < /tmp/postfix/accounts.cf
makeuserdb
# Copying virtual file
cp /tmp/postfix/virtual /etc/postfix/virtual

echo "Postfix configurations"
postmap /etc/postfix/vmailbox
postmap /etc/postfix/virtual
sed -i -r 's/DOCKER_MAIL_DOMAIN/'"$docker_mail_domain"'/g' /etc/postfix/main.cf
cat /tmp/vhost.tmp | sort | uniq >> /etc/postfix/vhost && rm /tmp/vhost.tmp

echo "Fixing permissions"
chown -R 5000:5000 /var/mail
mkdir -p /var/log/clamav && chown -R clamav:root /var/log/clamav

echo "Creating /etc/mailname"
echo $docker_mail_domain > /etc/mailname

echo "Configuring Spamassassin"
echo "required_hits 5.0" >> /etc/mail/spamassassin/local.cf
echo "report_safe 0" >> /etc/mail/spamassassin/local.cf
echo "required_score 5" >> /etc/mail/spamassassin/local.cf
echo "rewrite_header Subject ***SPAM***" >> /etc/mail/spamassassin/local.cf
cp /tmp/spamassassin/rules.cf /etc/spamassassin/

echo "Starting daemons"
/etc/init.d/rsyslog start
/etc/init.d/fam start
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
