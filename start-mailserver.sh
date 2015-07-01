#!/bin/sh

echo "Regenerating 'vmailbox' for given users"

echo "# WARNING: this file is auto-generated. Do not modify locally" > /etc/postfix/vmailbox
echo $docker_mail_users | sed -r 's/\[|\]|\x27| //g' | sed -r 's/,/\n/g' > /tmp/docker_mail_users
while IFS=$'|' read -r login pass
do
  # Setting variables for better readability
  user=$(echo ${login} | cut -d @ -f1)
  domain=$(echo ${login} | cut -d @ -f2)

  # Let's go!
  echo "user '${user}' for domain '${domain}' with password '${pass}'"
  echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
  userdb ${login} set uid=5000 gid=5000 home=/var/mail/${domain}/${user} mail=/var/mail/${domain}/${user}
  echo "${pass}" | userdbpw -md5 | userdb ${login} set systempw
  echo "${pass}" | saslpasswd2 -p -c -u ${domain} ${login}
  mkdir -p /var/mail/${domain}
  maildirmake /var/mail/${domain}/${user}
  echo ${domain} >> /tmp/vhost.tmp

done < /tmp/docker_mail_users
rm /tmp/docker_mail_users
makeuserdb

echo "Regenerating 'virtual' for given aliases"
echo $docker_mail_aliases | sed -r 's/\[|\]|\x27|//g' | sed -r 's/, /\n/g' > /tmp/docker_mail_aliases
echo "" > /etc/postfix/virtual
while IFS=$'|' read -r login aliases
do
  arr=$(echo $aliases | tr "," "\n")
  for alias in $arr
  do
    user=$(echo ${login} | cut -d @ -f1)
    domain=$(echo ${login} | cut -d @ -f2)
    echo "$alias@$domain redirects to $login"
    echo "$alias@$domain\t$login" >> /etc/postfix/virtual
  done
done < /tmp/docker_mail_aliases
rm /tmp/docker_mail_aliases

echo "Postfix configurations"
postmap /etc/postfix/vmailbox
touch /etc/postfix/virtual && postmap /etc/postfix/virtual
sed -i -r 's/DOCKER_MAIL_DOMAIN/'"$docker_mail_domain"'/g' /etc/postfix/main.cf
cat /tmp/vhost.tmp | sort | uniq >> /etc/postfix/vhost && rm /tmp/vhost.tmp

echo "Fixing permissions"
chown -R 5000:5000 /var/mail
mkdir -p /var/log/clamav && chown -R clamav:root /var/log/clamav

echo "Creating /etc/mailname"
echo $docker_mail_domain > /etc/mailname

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
