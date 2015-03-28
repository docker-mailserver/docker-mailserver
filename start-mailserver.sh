#!/bin/sh

echo "Regenerating 'vmailbox' for given users"

echo "docker_mail_users => $docker_mail_users"

echo "# WARNING: this file is auto-generated. Do not modify locally" > /etc/postfix/vmailbox
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
	mkdir -p /var/mail/ifusio.com
	maildirmake /var/mail/${domain}/${user}

done < /etc/postfix/docker-mail-users
makeuserdb

echo "Postmap configurations"
postmap /etc/postfix/vmailbox
postmap /etc/postfix/virtual

echo "Fixing permissions"
chown -R 5000:5000 /var/mail

echo "Creating /etc/mailname"
echo $docker_mail_domain > /etc/mailname

# echo "Mouting /var/lib/amavis as tmpfs"
# mount /var/lib/amavis

echo "Starting daemons"
/etc/init.d/fam start
/etc/init.d/saslauthd start
/etc/init.d/courier-authdaemon start
/etc/init.d/courier-imap start
/etc/init.d/spamassassin start
/etc/init.d/clamav-daemon start
/etc/init.d/amavis start
/etc/init.d/postfix start

echo "Listing SASL users"
sasldblistusers2

echo "Starting supervisord"
tail -f /var/log/mail.log