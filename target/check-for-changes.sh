#!/bin/bash

# create date for log output
log_date=$(date +"%Y-%m-%d %H:%M:%S ")
echo "${log_date} Start check-for-changes script."

# change directory
cd /tmp/docker-mailserver

# Check postfix-accounts.cf exist else break
if [ ! -f postfix-accounts.cf ]; then
   echo "${log_date} postfix-accounts.cf is missing! This should not run! Exit!"
   exit
fi

# Verify checksum file exists; must be prepared by start-mailserver.sh
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum
if [ ! -f $CHKSUM_FILE ]; then
   echo "${log_date} ${CHKSUM_FILE} is missing! Start script failed? Exit!"
   exit
fi

# Determine postmaster address, duplicated from start-mailserver.sh
# This script previously didn't work when POSTMASTER_ADDRESS was empty
if [[ -n "${OVERRIDE_HOSTNAME}" ]]; then
  DOMAINNAME=$(echo "${OVERRIDE_HOSTNAME}" | sed s/[^.]*.//)
else
  DOMAINNAME="$(hostname -d)"
fi
PM_ADDRESS="${POSTMASTER_ADDRESS:=postmaster@${DOMAINNAME}}"
echo "${log_date} Using postmaster address ${PM_ADDRESS}"

# Create an array of files to monitor, must be the same as in start-mailserver.sh
declare -a cf_files=()
for file in postfix-accounts.cf postfix-virtual.cf postfix-aliases.cf; do
  [ -f "$file" ] && cf_files+=("$file")
done

# Wait to make sure server is up before we start
sleep 10

# Run forever
while true; do

# recreate logdate
log_date=$(date +"%Y-%m-%d %H:%M:%S ")

# Get chksum and check it, no need to lock config yet
chksum=$(sha512sum -c --ignore-missing $CHKSUM_FILE)

if [[ $chksum == *"FAIL"* ]]; then
	echo "${log_date} Change detected"

	# Bug alert! This overwrites the alias set by start-mailserver.sh
	# Take care that changes in one script are propagated to the other
        # Also note that changes are performed in place and are not atomic
        # We should fix that and write to temporary files, stop, swap and start

        # Lock configuration while working
        # Not fixing indentation yet to reduce diff (fix later in separate commit)
        (
          flock -e 200

	#regen postix aliases.
	echo "root: ${PM_ADDRESS}" > /etc/aliases
	if [ -f /tmp/docker-mailserver/postfix-aliases.cf ]; then
		cat /tmp/docker-mailserver/postfix-aliases.cf>>/etc/aliases
	fi
	postalias /etc/aliases

	#regen postfix accounts.
	echo -n > /etc/postfix/vmailbox
	echo -n > /etc/dovecot/userdb
	if [ -f /tmp/docker-mailserver/postfix-accounts.cf -a "$ENABLE_LDAP" != 1 ]; then
		sed -i 's/\r//g' /tmp/docker-mailserver/postfix-accounts.cf
		echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox
		# Checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
		sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf
		chown dovecot:dovecot /etc/dovecot/userdb
		chmod 640 /etc/dovecot/userdb
		sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
		sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

		# rebuild relay host
		if [ ! -z "$RELAY_HOST" ]; then
			# keep old config
			echo -n > /etc/postfix/sasl_passwd
			echo -n > /etc/postfix/relayhost_map
			if [ ! -z "$SASL_PASSWD" ]; then
				echo "$SASL_PASSWD" >> /etc/postfix/sasl_passwd
			fi
			# add domain-specific auth from config file
			if [ -f /tmp/docker-mailserver/postfix-sasl-password.cf ]; then
				while read line; do
					if ! echo "$line" | grep -q -e "\s*#"; then
						echo "$line" >> /etc/postfix/sasl_passwd
					fi
				done < /tmp/docker-mailserver/postfix-sasl-password.cf
			fi
			# add default relay
			if [ ! -z "$RELAY_USER" ] && [ ! -z "$RELAY_PASSWORD" ]; then
				echo "[$RELAY_HOST]:$RELAY_PORT		$RELAY_USER:$RELAY_PASSWORD" >> /etc/postfix/sasl_passwd
			fi
			# add relay maps from file
			if [ -f /tmp/docker-mailserver/postfix-relaymap.cf ]; then
				while read line; do
					if ! echo "$line" | grep -q -e "\s*#"; then
						echo "$line" >> /etc/postfix/relayhost_map
					fi
				done < /tmp/docker-mailserver/postfix-relaymap.cf
			fi
		fi

		# Creating users
		# 'pass' is encrypted
		# comments and empty lines are ignored
		grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-accounts.cf | while IFS=$'|' read login pass
		do
			# Setting variables for better readability
			user=$(echo ${login} | cut -d @ -f1)
			domain=$(echo ${login} | cut -d @ -f2)
			# Let's go!
			echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
			# User database for dovecot has the following format:
			# user:password:uid:gid:(gecos):home:(shell):extra_fields
			# Example :
			# ${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::userdb_mail=maildir:/var/mail/${domain}/${user}
			echo "${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::" >> /etc/dovecot/userdb
			mkdir -p /var/mail/${domain}/${user}
			# Copy user provided sieve file, if present
			test -e /tmp/docker-mailserver/${login}.dovecot.sieve && cp /tmp/docker-mailserver/${login}.dovecot.sieve /var/mail/${domain}/${user}/.dovecot.sieve
			echo ${domain} >> /tmp/vhost.tmp
			# add domains to relayhost_map
			if [ ! -z "$RELAY_HOST" ]; then
				if ! grep -q -e "^@${domain}\s" /etc/postfix/relayhost_map; then
					echo "@${domain}		[$RELAY_HOST]:$RELAY_PORT" >> /etc/postfix/relayhost_map
				fi
			fi
		done
	fi
	if [ -f /etc/postfix/sasl_passwd ]; then
		chown root:root /etc/postfix/sasl_passwd
		chmod 0600 /etc/postfix/sasl_passwd
	fi
	if [ -f /etc/postfix/relayhost_map ]; then
		chown root:root /etc/postfix/relayhost_map
		chmod 0600 /etc/postfix/relayhost_map
	fi
	if [ -f postfix-virtual.cf ]; then
	# regen postfix aliases
	echo -n > /etc/postfix/virtual
	echo -n > /etc/postfix/regexp
	if [ -f /tmp/docker-mailserver/postfix-virtual.cf ]; then
		# Copying virtual file
		cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual
		while read from to
		do
			# Setting variables for better readability
			uname=$(echo ${from} | cut -d @ -f1)
			domain=$(echo ${from} | cut -d @ -f2)
			# if they are equal it means the line looks like: "user1	 other@domain.tld"
			test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
		done < /tmp/docker-mailserver/postfix-virtual.cf
	fi
	if [ -f /tmp/docker-mailserver/postfix-regexp.cf ]; then
		# Copying regexp alias file
		cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
		sed -i -e '/^virtual_alias_maps/{
		s/ regexp:.*//
		s/$/ regexp:\/etc\/postfix\/regexp/
		}' /etc/postfix/main.cf
	fi
	fi
	# Set vhost 
	if [ -f /tmp/vhost.tmp ]; then
		cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
	fi
	
	# Set right new if needed
	if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
		chown -R 5000:5000 /var/mail
	fi
	
	# Restart of the postfix
	supervisorctl restart postfix
	
	# Prevent restart of dovecot when smtp_only=1
	if [ ! $SMTP_ONLY = 1 ]; then
		supervisorctl restart dovecot
	fi 

	echo "${log_date} Update checksum"
	sha512sum ${cf_files[@]/#/--tag } >$CHKSUM_FILE

        ) 200<postfix-accounts.cf # end lock
fi

sleep 1
done
