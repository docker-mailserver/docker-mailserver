#!/usr/bin/env bash

function log {
  echo "[$(date --rfc-3339=seconds)] $*"
}

# summap is an associative array.
# Keys are token-filename combinations, values are checksums of files.
declare -A summap

# addsum adds checksums for files to the array.
# It has one required argument (a token to differentiate file sets) and one or
# more optional arguments (a list of filenames).
# Tokens differentiate file sets, so the same array holds multiple file sets.
# If the token is not supplied, the function returns -1.
# If any file is not found, the function returns -2.
# Otherwise, the function returns 0.
function addsum {
  if [ $# -eq 0 ]; then
    log No token passed
    return -1
  fi
  token=$1
  shift
  while (( "$#" )); do
    fname=$1
    shift
    if [ -f ${fname} ]; then
      key=${token}/${fname}
      summap[${key}]=$(sha512sum ${fname})
    else
      log No such file at ${fname}
      return -2
    fi
  done
  return 0
}

# testsum checks each file for changes.
# It has one required argument (a token to differentiate file sets).
# All files associated with that token will be checked.
# If a file is not found, the script exits with a log message.
# The return value of the function is equal to the number of changed files.
# NB: the array is updated when files are changed!
function testsum {
  if [ $# -eq 0 ]; then
    log No token passed
    return -1
  fi
  token=$1
  changed=0
  for val in "${!summap[@]}"; do
    vtoken=$(echo $val | cut -d '/' -f1 -)
    if [ "$vtoken" == "$token" ]; then
      fname=$(echo $val | cut -d '/' -f2- -)
      if [ -f ${fname} ]; then
        newsum=$(sha512sum ${fname})
        if [ "$newsum" != "${summap[${token}/${fname}]}" ]; then
          # log File changed: ${fname}
          changed=$((changed+1))
          summap[${token}/${fname}]=$newsum
        fi
      else
        log No such file at ${fname}
        return -2
      fi
    fi
  done
  return ${changed}
}

# This function tests addsum and testsum.
function test_script {
  failed=""
  passed=""
  testno=0

  # Calling addsum without token should return -1 (255).
  testno=$((testno+1))
  addsum > /dev/null
  retval=$?
  if [ $retval -eq 255 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Calling addsum with token but no files should return 0.
  testno=$((testno+1))
  addsum first >/dev/null
  retval=$?
  if [ $retval -eq 0 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Calling addsum with a missing file should return -2 (254).
  testno=$((testno+1))
  rm -f testme
  addsum first testme >/dev/null
  retval=$?
  if [ $retval -eq 254 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Calling addsum with token and file should return 0.
  testno=$((testno+1))
  ls > testme
  addsum first testme >/dev/null
  retval=$?
  if [ $retval -eq 0 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Calling testsum without token should return -1 (255).
  testno=$((testno+1))
  testsum >/dev/null
  retval=$?
  if [ $retval -eq 255 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Calling testsum with token but no associated files should return 0.
  testno=$((testno+1))
  testsum second >/dev/null
  retval=$?
  if [ $retval -eq 0 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Calling testsum with token and unchanged file should return 0.
  testno=$((testno+1))
  testsum first >/dev/null
  retval=$?
  if [ $retval -eq 0 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Calling testsum with token and changed file should return 1.
  testno=$((testno+1))
  ls >> testme
  testsum first >/dev/null
  retval=$?
  if [ $retval -eq 1 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Array should have been updated in previous run, so should return 0.
  testno=$((testno+1))
  testsum first >/dev/null
  retval=$?
  if [ $retval -eq 0 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # Calling testsum when file is missing should return -2 (254).
  testno=$((testno+1))
  rm testme
  testsum first >/dev/null
  retval=$?
  if [ $retval -eq 254 ]; then passed="$passed $testno"; else failed="$failed $testno"; fi

  # All tests must pass!
  if [[ $(echo $failed | wc -w) -eq 0 && $(echo $passed | wc -w) -eq $testno ]]; then
    exit 0
  else
    echo "Tests passed: $passed, failed: $failed"
    exit 1
  fi
}

# ---

# Test by passing "test" as first argument.
if [[ ! -z "$1" && "$1" = "test" ]]; then
  test_script
fi

# Prevent an early start.
sleep 5

log "Start check-for-changes script."

# Change directory.
cd /tmp/docker-mailserver

# If SSL_TYPE is set, populate array with SSL files.
if [ ! -z $SSL_TYPE ]; then
  addsum ssl ${SSL_CERT_PATH} ${SSL_KEY_PATH}
fi

# If ENABLE_LDAP is *not* set, populate array with Postfix files.
if [ -z $ENABLE_LDAP ]; then
  addsum postfix postfix-accounts.cf
  # postfix-virtual.cf is optional!
  if [ -f postfix-virtual.cf ]; then
    addsum postfix postfix-virtual.cf
  fi
fi

function restart {
  supervisorctl restart postfix
  if [ ! $SMTP_ONLY = 1 ]; then
    supervisorctl restart dovecot
  fi
}

# Infinite loop
while true; do

  testsum ssl
  retval=$?
  if [ $retval -eq 254 ]; then
    log "SSL files missing, exiting"
    exit 1
  elif [ $retval -ne 0 ]; then
    log "SSL files changed, restarting"
    restart
  fi

  testsum postfix
  retval=$?
  if [ $retval -eq 254 ]; then
    log "Postfix files missing, exiting"
    exit 1
  elif [ $retval -ne 0 ]; then
    log "Postfix files changed, restarting"

    # Ensure postfix-accounts.cf has no returns and ends with a newline!
	  sed -i 's/\r//g' postfix-accounts.cf
    sed -i -e '$a\' postfix-accounts.cf

    # Ensure LDAP is disabled and passwdfile is enabled for Dovecot.
		sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
		sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

		# Rebuild relay host configuration.
		if [ ! -z "$RELAY_HOST" ]; then
			# keep old config
			echo -n > /etc/postfix/sasl_passwd
			echo -n > /etc/postfix/relayhost_map
			if [ ! -z "$SASL_PASSWD" ]; then
				echo "$SASL_PASSWD" >> /etc/postfix/sasl_passwd
			fi
			# add domain-specific auth from config file
			if [ -f postfix-sasl-password.cf ]; then
				while read line; do
					if ! echo "$line" | grep -q -e "\s*#"; then
						echo "$line" >> /etc/postfix/sasl_passwd
					fi
				done < postfix-sasl-password.cf
			fi
			# add default relay
			if [ ! -z "$RELAY_USER" ] && [ ! -z "$RELAY_PASSWORD" ]; then
				echo "[$RELAY_HOST]:$RELAY_PORT		$RELAY_USER:$RELAY_PASSWORD" >> /etc/postfix/sasl_passwd
			fi
			# add relay maps from file
			if [ -f postfix-relaymap.cf ]; then
				while read line; do
					if ! echo "$line" | grep -q -e "\s*#"; then
						echo "$line" >> /etc/postfix/relayhost_map
					fi
				done < postfix-relaymap.cf
			fi

      # Set ownership and permissions of rebuilt files.
  		chown root:root /etc/postfix/sasl_passwd
  		chmod 0600 /etc/postfix/sasl_passwd
  		chown root:root /etc/postfix/relayhost_map
  		chmod 0600 /etc/postfix/relayhost_map
		fi

		# Creating users
		# 'pass' is encrypted
		# comments and empty lines are ignored
    echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox
    echo -n > /etc/dovecot/userdb
		grep -v "^\s*$\|^\s*\#" postfix-accounts.cf | while IFS=$'|' read login pass
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
			test -e ${login}.dovecot.sieve && cp ${login}.dovecot.sieve /var/mail/${domain}/${user}/.dovecot.sieve
			echo ${domain} >> /tmp/vhost.tmp

			# add domains to relayhost_map
			if [ ! -z "$RELAY_HOST" ]; then
				if ! grep -q -e "^@${domain}\s" /etc/postfix/relayhost_map; then
					echo "@${domain}		[$RELAY_HOST]:$RELAY_PORT" >> /etc/postfix/relayhost_map
				fi
			fi
		done

    # Set ownership and permissions of rebuilt file.
    chown dovecot:dovecot /etc/dovecot/userdb
		chmod 640 /etc/dovecot/userdb

    # Rebuild virtual files if necessary.
  	if [ -f postfix-virtual.cf ]; then
      # Regenerate Postfix virtual table and regexp table.
  		cp -f postfix-virtual.cf /etc/postfix/virtual
  		while read from to
  		do
  			# Setting variables for better readability
  			uname=$(echo ${from} | cut -d @ -f1)
  			domain=$(echo ${from} | cut -d @ -f2)
  			# if they are equal it means the line looks like: "user1     other@domain.tld"
  			test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
  		done < postfix-virtual.cf

    	if [ -f postfix-regexp.cf ]; then
    		# Copying regexp alias file
    		cp -f postfix-regexp.cf /etc/postfix/regexp
    		sed -i -e '/^virtual_alias_maps/{
    		s/ regexp:.*//
    		s/$/ regexp:\/etc\/postfix\/regexp/
    		}' /etc/postfix/main.cf
    	fi

      # Set vhost.
    	if [ -f /tmp/vhost.tmp ]; then
    		cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
    	fi
  	fi

    # Set mail spool permissions.
  	if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
  		chown -R 5000:5000 /var/mail
  	fi

    # Restart Postfix (and Dovecot if necessary).
    restart
  fi

  sleep 1
done
