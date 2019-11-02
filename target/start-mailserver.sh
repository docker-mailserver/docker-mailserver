#!/bin/bash

##########################################################################
# >> DEFAULT VARS
#
# add them here.
# Example: DEFAULT_VARS["KEY"]="VALUE"
##########################################################################
declare -A DEFAULT_VARS
DEFAULT_VARS["ENABLE_CLAMAV"]="${ENABLE_CLAMAV:="0"}"
DEFAULT_VARS["ENABLE_SPAMASSASSIN"]="${ENABLE_SPAMASSASSIN:="0"}"
DEFAULT_VARS["ENABLE_POP3"]="${ENABLE_POP3:="0"}"
DEFAULT_VARS["ENABLE_FAIL2BAN"]="${ENABLE_FAIL2BAN:="0"}"
DEFAULT_VARS["ENABLE_MANAGESIEVE"]="${ENABLE_MANAGESIEVE:="0"}"
DEFAULT_VARS["ENABLE_FETCHMAIL"]="${ENABLE_FETCHMAIL:="0"}"
DEFAULT_VARS["FETCHMAIL_POLL"]="${FETCHMAIL_POLL:="300"}"
DEFAULT_VARS["ENABLE_LDAP"]="${ENABLE_LDAP:="0"}"
DEFAULT_VARS["LDAP_START_TLS"]="${LDAP_START_TLS:="no"}"
DEFAULT_VARS["DOVECOT_TLS"]="${DOVECOT_TLS:="no"}"
DEFAULT_VARS["ENABLE_POSTGREY"]="${ENABLE_POSTGREY:="0"}"
DEFAULT_VARS["POSTGREY_DELAY"]="${POSTGREY_DELAY:="300"}"
DEFAULT_VARS["POSTGREY_MAX_AGE"]="${POSTGREY_MAX_AGE:="35"}"
DEFAULT_VARS["POSTGREY_AUTO_WHITELIST_CLIENTS"]="${POSTGREY_AUTO_WHITELIST_CLIENTS:="5"}"
DEFAULT_VARS["POSTGREY_TEXT"]="${POSTGREY_TEXT:="Delayed by postgrey"}"
DEFAULT_VARS["POSTFIX_MESSAGE_SIZE_LIMIT"]="${POSTFIX_MESSAGE_SIZE_LIMIT:="10240000"}"  # ~10 MB by default
DEFAULT_VARS["POSTFIX_MAILBOX_SIZE_LIMIT"]="${POSTFIX_MAILBOX_SIZE_LIMIT:="0"}"        # no limit by default
DEFAULT_VARS["ENABLE_SASLAUTHD"]="${ENABLE_SASLAUTHD:="0"}"
DEFAULT_VARS["SMTP_ONLY"]="${SMTP_ONLY:="0"}"
DEFAULT_VARS["DMS_DEBUG"]="${DMS_DEBUG:="0"}"
DEFAULT_VARS["OVERRIDE_HOSTNAME"]="${OVERRIDE_HOSTNAME}"
DEFAULT_VARS["POSTSCREEN_ACTION"]="${POSTSCREEN_ACTION:="enforce"}"
DEFAULT_VARS["SPOOF_PROTECTION"]="${SPOOF_PROTECTION:="0"}"
DEFAULT_VARS["TLS_LEVEL"]="${TLS_LEVEL:="modern"}"
DEFAULT_VARS["ENABLE_SRS"]="${ENABLE_SRS:="0"}"
DEFAULT_VARS["REPORT_RECIPIENT"]="${REPORT_RECIPIENT:="0"}"
DEFAULT_VARS["LOGROTATE_INTERVAL"]="${LOGROTATE_INTERVAL:=${REPORT_INTERVAL:-"daily"}}"
DEFAULT_VARS["LOGWATCH_INTERVAL"]="${LOGWATCH_INTERVAL:="none"}"
DEFAULT_VARS["VIRUSMAILS_DELETE_DELAY"]="${VIRUSMAILS_DELETE_DELAY:="7"}"

##########################################################################
# << DEFAULT VARS
##########################################################################

##########################################################################
# >> GLOBAL VARS
#
# add your global script variables here.
#
# Example: KEY="VALUE"
##########################################################################
HOSTNAME="$(hostname -f)"
DOMAINNAME="$(hostname -d)"
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum
##########################################################################
# << GLOBAL VARS
##########################################################################


##########################################################################
# >> REGISTER FUNCTIONS
#
# add your new functions/methods here.
#
# NOTE: position matters when registering a function in stacks. First in First out
# 		Execution Logic:
# 			> check functions
# 			> setup functions
# 			> fix functions
# 			> misc functions
# 			> start-daemons
#
# Example:
# if [ CONDITION IS MET ]; then
#   _register_{setup,fix,check,start}_{functions,daemons} "$FUNCNAME"
# fi
#
# Implement them in the section-group: {check,setup,fix,start}
##########################################################################
function register_functions() {
	notify 'taskgrp' 'Initializing setup'
	notify 'task' 'Registering check,setup,fix,misc and start-daemons functions'

	################### >> check funcs

	_register_check_function "_check_environment_variables"
	_register_check_function "_check_hostname"

	################### << check funcs

	################### >> setup funcs

	_register_setup_function "_setup_default_vars"
	_register_setup_function "_setup_file_permissions"

	if [ "$ENABLE_ELK_FORWARDER" = 1 ]; then
		_register_setup_function "_setup_elk_forwarder"
	fi

	if [ "$SMTP_ONLY" != 1 ]; then
		_register_setup_function "_setup_dovecot"
                _register_setup_function "_setup_dovecot_dhparam"
		_register_setup_function "_setup_dovecot_local_user"
	fi

	if [ "$ENABLE_LDAP" = 1 ];then
		_register_setup_function "_setup_ldap"
	fi

	if [ "$ENABLE_SASLAUTHD" = 1 ];then
		_register_setup_function "_setup_saslauthd"
	fi

	if [ "$ENABLE_POSTGREY" = 1 ];then
		_register_setup_function "_setup_postgrey"
	fi

	_register_setup_function "_setup_dkim"
	_register_setup_function "_setup_ssl"
	_register_setup_function "_setup_docker_permit"

	_register_setup_function "_setup_mailname"
	_register_setup_function "_setup_amavis"
	_register_setup_function "_setup_dmarc_hostname"
	_register_setup_function "_setup_postfix_hostname"
	_register_setup_function "_setup_dovecot_hostname"

	_register_setup_function "_setup_postfix_smtputf8"
	_register_setup_function "_setup_postfix_sasl"
	_register_setup_function "_setup_postfix_sasl_password"
	_register_setup_function "_setup_security_stack"
	_register_setup_function "_setup_postfix_aliases"
	_register_setup_function "_setup_postfix_vhost"
	_register_setup_function "_setup_postfix_dhparam"
	_register_setup_function "_setup_postfix_postscreen"
	_register_setup_function "_setup_postfix_sizelimits"

  if [ "$SPOOF_PROTECTION" = 1  ]; then
		_register_setup_function "_setup_spoof_protection"
	fi

	if [ "$ENABLE_SRS" = 1 ];  then
		_register_setup_function "_setup_SRS"
		_register_start_daemon "_start_daemons_postsrsd"
	fi

  _register_setup_function "_setup_postfix_access_control"

	if [ ! -z "$AWS_SES_HOST" -a ! -z "$AWS_SES_USERPASS" ]; then
		_register_setup_function "_setup_postfix_relay_hosts"
	fi

	if [ ! -z "$DEFAULT_RELAY_HOST" ]; then
		_register_setup_function "_setup_postfix_default_relay_host"
	fi

	if [ ! -z "$RELAY_HOST" ]; then
		_register_setup_function "_setup_postfix_relay_hosts"
	fi

	if [ "$ENABLE_POSTFIX_VIRTUAL_TRANSPORT" = 1  ]; then
		_register_setup_function "_setup_postfix_virtual_transport"
	fi

	_register_setup_function "_setup_postfix_override_configuration"

  _register_setup_function "_setup_environment"
  _register_setup_function "_setup_logrotate"

	if [ "$PFLOGSUMM_TRIGGER" != "none" ]; then
		_register_setup_function "_setup_mail_summary"
	fi

	if [ "$LOGWATCH_TRIGGER" != "none" ]; then
		_register_setup_function "_setup_logwatch"
	fi


        # Compute last as the config files are modified in-place
        _register_setup_function "_setup_chksum_file"

	################### << setup funcs

	################### >> fix funcs

	_register_fix_function "_fix_var_mail_permissions"
	_register_fix_function "_fix_var_amavis_permissions"
	if [ "$ENABLE_CLAMAV" = 0 ]; then
        	_register_fix_function "_fix_cleanup_clamav"
	fi
	if [ "$ENABLE_SPAMASSASSIN" = 0 ]; then
		_register_fix_function "_fix_cleanup_spamassassin"
	fi

	################### << fix funcs

	################### >> misc funcs

	_register_misc_function "_misc_save_states"

	################### << misc funcs

	################### >> daemon funcs

	_register_start_daemon "_start_daemons_cron"
	_register_start_daemon "_start_daemons_rsyslog"

	if [ "$ENABLE_ELK_FORWARDER" = 1 ]; then
		_register_start_daemon "_start_daemons_filebeat"
	fi

	if [ "$SMTP_ONLY" != 1 ]; then
		_register_start_daemon "_start_daemons_dovecot"
	fi

	# needs to be started before saslauthd
	_register_start_daemon "_start_daemons_opendkim"
	_register_start_daemon "_start_daemons_opendmarc"

	#postfix uses postgrey, needs to be started before postfix
	if [ "$ENABLE_POSTGREY" = 1 ]; then
		_register_start_daemon "_start_daemons_postgrey"
	fi

	_register_start_daemon "_start_daemons_postfix"

	if [ "$ENABLE_SASLAUTHD" = 1 ];then
		_register_start_daemon "_start_daemons_saslauthd"
	fi

	# care needs to run after postfix
	if [ "$ENABLE_FAIL2BAN" = 1 ]; then
		_register_start_daemon "_start_daemons_fail2ban"
	fi

	if [ "$ENABLE_FETCHMAIL" = 1 ]; then
		_register_start_daemon "_start_daemons_fetchmail"
	fi

	if [ "$ENABLE_CLAMAV" = 1 ]; then
		_register_start_daemon "_start_daemons_clamav"
	fi
    # Change detector
    if [ "$ENABLE_LDAP" = 0 ]; then
	    _register_start_daemon "_start_changedetector"
    fi

	_register_start_daemon "_start_daemons_amavis"
	################### << daemon funcs
}
##########################################################################
# << REGISTER FUNCTIONS
##########################################################################



# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# >>


##########################################################################
# >> CONSTANTS
##########################################################################
declare -a FUNCS_SETUP
declare -a FUNCS_FIX
declare -a FUNCS_CHECK
declare -a FUNCS_MISC
declare -a DAEMONS_START
declare -A HELPERS_EXEC_STATE
##########################################################################
# << CONSTANTS
##########################################################################


##########################################################################
# >> protected register_functions
##########################################################################
function _register_start_daemon() {
	DAEMONS_START+=($1)
	notify 'inf' "$1() registered"
}

function _register_setup_function() {
	FUNCS_SETUP+=($1)
	notify 'inf' "$1() registered"
}

function _register_fix_function() {
	FUNCS_FIX+=($1)
	notify 'inf' "$1() registered"
}

function _register_check_function() {
	FUNCS_CHECK+=($1)
	notify 'inf' "$1() registered"
}

function _register_misc_function() {
	FUNCS_MISC+=($1)
	notify 'inf' "$1() registered"
}
##########################################################################
# << protected register_functions
##########################################################################


function notify () {
	c_red="\e[0;31m"
	c_green="\e[0;32m"
	c_brown="\e[0;33m"
	c_blue="\e[0;34m"
	c_bold="\033[1m"
	c_reset="\e[0m"

	notification_type=$1
	notification_msg=$2
	notification_format=$3
	msg=""

	case "${notification_type}" in
		'taskgrp')
			msg="${c_bold}${notification_msg}${c_reset}"
			;;
		'task')
			if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
				msg="  ${notification_msg}${c_reset}"
			fi
			;;
		'inf')
			if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
				msg="${c_green}  * ${notification_msg}${c_reset}"
			fi
			;;
		'started')
			msg="${c_green} ${notification_msg}${c_reset}"
			;;
		'warn')
			msg="${c_brown}  * ${notification_msg}${c_reset}"
			;;
		'err')
			msg="${c_red}  * ${notification_msg}${c_reset}"
			;;
		'fatal')
			msg="${c_red}Error: ${notification_msg}${c_reset}"
			;;
		*)
			msg=""
			;;
	esac

	case "${notification_format}" in
		'n')
			options="-ne"
	  	;;
		*)
  		options="-e"
			;;
	esac

	[[ ! -z "${msg}" ]] && echo $options "${msg}"
}

function defunc() {
	notify 'fatal' "Please fix your configuration. Exiting..."
	exit 1
}

function display_startup_daemon() {
  $1 &>/dev/null
  res=$?
  if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
	  if [ $res = 0 ]; then
			notify 'started' " [ OK ]"
		else
	  	echo "false"
			notify 'err' " [ FAILED ]"
		fi
  fi
	return $res
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, except you know exactly what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# <<



##########################################################################
# >> Check Stack
#
# Description: Place functions for initial check of container sanity
##########################################################################
function check() {
	notify 'taskgrp' 'Checking configuration'
	for _func in "${FUNCS_CHECK[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _check_hostname() {
	notify "task" "Check that hostname/domainname is provided or overidden (no default docker hostname/kubernetes) [$FUNCNAME]"

	if [[ ! -z ${DEFAULT_VARS["OVERRIDE_HOSTNAME"]} ]]; then
		export HOSTNAME=${DEFAULT_VARS["OVERRIDE_HOSTNAME"]}
		export DOMAINNAME=$(echo $HOSTNAME | sed s/[^.]*.//)
	fi

	notify 'inf' "Domain has been set to $DOMAINNAME"
	notify 'inf' "Hostname has been set to $HOSTNAME"

	if ( ! echo $HOSTNAME | grep -E '^(\S+[.]\S+)$' > /dev/null ); then
		notify 'err' "Setting hostname/domainname is required"
		kill `cat /var/run/supervisord.pid` && return 1
	else
		return 0
	fi
}

function _check_environment_variables() {
	notify "task" "Check that there are no conflicts with env variables [$FUNCNAME]"
	return 0
}
##########################################################################
# << Check Stack
##########################################################################


##########################################################################
# >> Setup Stack
#
# Description: Place functions for functional configurations here
##########################################################################
function setup() {
	notify 'taskgrp' 'Configuring mail server'
	for _func in "${FUNCS_SETUP[@]}";do
		$_func
	done
}

function _setup_default_vars() {
	notify 'task' "Setting up default variables [$FUNCNAME]"

	# update POSTMASTER_ADDRESS - must be done done after _check_hostname()
	DEFAULT_VARS["POSTMASTER_ADDRESS"]="${POSTMASTER_ADDRESS:=postmaster@${DOMAINNAME}}"

	# update REPORT_SENDER - must be done done after _check_hostname()
	DEFAULT_VARS["REPORT_SENDER"]="${REPORT_SENDER:=mailserver-report@${HOSTNAME}}"
	DEFAULT_VARS["PFLOGSUMM_SENDER"]="${PFLOGSUMM_SENDER:=${REPORT_SENDER}}"

	# set PFLOGSUMM_TRIGGER here for backwards compatibility
	# when REPORT_RECIPIENT is on the old method should be used
	if [ "$REPORT_RECIPIENT" == "0" ]; then
		DEFAULT_VARS["PFLOGSUMM_TRIGGER"]="${PFLOGSUMM_TRIGGER:="none"}"
	else
		DEFAULT_VARS["PFLOGSUMM_TRIGGER"]="${PFLOGSUMM_TRIGGER:="logrotate"}"
	fi

	# Expand address to simplify the rest of the script
	if [ "$REPORT_RECIPIENT" == "0" ] || [ "$REPORT_RECIPIENT" == "1" ]; then
		REPORT_RECIPIENT="$POSTMASTER_ADDRESS"
		DEFAULT_VARS["REPORT_RECIPIENT"]="${REPORT_RECIPIENT}"
	fi
	DEFAULT_VARS["PFLOGSUMM_RECIPIENT"]="${PFLOGSUMM_RECIPIENT:=${REPORT_RECIPIENT}}"
	DEFAULT_VARS["LOGWATCH_RECIPIENT"]="${LOGWATCH_RECIPIENT:=${REPORT_RECIPIENT}}"

	for var in ${!DEFAULT_VARS[@]}; do
		echo "export $var=\"${DEFAULT_VARS[$var]}\"" >> /root/.bashrc
		[ $? != 0 ] && notify 'err' "Unable to set $var=${DEFAULT_VARS[$var]}" && kill -15 `cat /var/run/supervisord.pid` && return 1
		notify 'inf' "Set $var=${DEFAULT_VARS[$var]}"
	done
}

# File/folder permissions are fine when using docker volumes, but may be wrong
# when file system folders are mounted into the container.
# Set the expected values and create missing folders/files just in case.
function _setup_file_permissions() {
	notify 'task' "Setting file/folder permissions"

	mkdir -p /var/log/supervisor

	mkdir -p /var/log/mail
	chown syslog:root /var/log/mail

	touch /var/log/mail/clamav.log
	chown clamav:adm /var/log/mail/clamav.log
	chmod 640 /var/log/mail/clamav.log

	touch /var/log/mail/freshclam.log
	chown clamav:adm /var/log/mail/freshclam.log
	chmod 640 /var/log/mail/freshclam.log
}

function _setup_chksum_file() {
        notify 'task' "Setting up configuration checksum file"


        if [ -d /tmp/docker-mailserver ]; then
          pushd /tmp/docker-mailserver

          declare -a cf_files=()
          for file in postfix-accounts.cf postfix-virtual.cf postfix-aliases.cf; do
            [ -f "$file" ] && cf_files+=("$file")
          done

          notify 'inf' "Creating $CHKSUM_FILE"
          sha512sum ${cf_files[@]/#/--tag } >$CHKSUM_FILE

          popd
        else
          # We could just skip the file, but perhaps config can be added later?
          # If so it must be processed by the check for changes script
          notify 'inf' "Creating empty $CHKSUM_FILE (no config)"
          touch $CHKSUM_FILE
        fi
}

function _setup_mailname() {
	notify 'task' 'Setting up Mailname'

	notify 'inf' "Creating /etc/mailname"
	echo $DOMAINNAME > /etc/mailname
}

function _setup_amavis() {
	notify 'task' 'Setting up Amavis'

	notify 'inf' "Applying hostname to /etc/amavis/conf.d/05-node_id"
	sed -i 's/^#\$myhostname = "mail.example.com";/\$myhostname = "'$HOSTNAME'";/' /etc/amavis/conf.d/05-node_id
}

function _setup_dmarc_hostname() {
	notify 'task' 'Setting up dmarc'

	notify 'inf' "Applying hostname to /etc/opendmarc.conf"
	sed -i -e 's/^AuthservID.*$/AuthservID          '$HOSTNAME'/g' \
	       -e 's/^TrustedAuthservIDs.*$/TrustedAuthservIDs  '$HOSTNAME'/g' /etc/opendmarc.conf
}

function _setup_postfix_hostname() {
	notify 'task' 'Applying hostname and domainname to Postfix'

	notify 'inf' "Applying hostname to /etc/postfix/main.cf"
	postconf -e "myhostname = $HOSTNAME"
	postconf -e "mydomain = $DOMAINNAME"
}

function _setup_dovecot_hostname() {
	notify 'task' 'Applying hostname to Dovecot'

	notify 'inf' "Applying hostname to /etc/dovecot/conf.d/15-lda.conf"
	sed -i 's/^#hostname =.*$/hostname = '$HOSTNAME'/g' /etc/dovecot/conf.d/15-lda.conf
}

function _setup_dovecot() {
	notify 'task' 'Setting up Dovecot'

        # Moved from docker file, copy or generate default self-signed cert
        if [ -f /var/mail-state/lib-dovecot/dovecot.pem -a "$ONE_DIR" = 1 ]; then
                notify 'inf' "Copying default dovecot cert"
                cp /var/mail-state/lib-dovecot/dovecot.key /etc/dovecot/ssl/
                cp /var/mail-state/lib-dovecot/dovecot.pem /etc/dovecot/ssl/
        fi
        if [ ! -f /etc/dovecot/ssl/dovecot.pem ]; then
                notify 'inf' "Generating default dovecot cert"
                pushd /usr/share/dovecot
                ./mkcert.sh
                popd

                if [ "$ONE_DIR" = 1 ];then
                        mkdir -p /var/mail-state/lib-dovecot
                        cp /etc/dovecot/ssl/dovecot.key /var/mail-state/lib-dovecot/
                        cp /etc/dovecot/ssl/dovecot.pem /var/mail-state/lib-dovecot/
                fi
        fi

	cp -a /usr/share/dovecot/protocols.d /etc/dovecot/
	# Disable pop3 (it will be eventually enabled later in the script, if requested)
	mv /etc/dovecot/protocols.d/pop3d.protocol /etc/dovecot/protocols.d/pop3d.protocol.disab
	mv /etc/dovecot/protocols.d/managesieved.protocol /etc/dovecot/protocols.d/managesieved.protocol.disab
	sed -i -e 's/#ssl = yes/ssl = yes/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#port = 993/port = 993/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#port = 995/port = 995/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#ssl = yes/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf
	sed -i 's/^postmaster_address = .*$/postmaster_address = '$POSTMASTER_ADDRESS'/g' /etc/dovecot/conf.d/15-lda.conf

	# Enable Managesieve service by setting the symlink
	# to the configuration file Dovecot will actually find
	if [ "$ENABLE_MANAGESIEVE" = 1 ]; then
		notify 'inf' "Sieve management enabled"
		mv /etc/dovecot/protocols.d/managesieved.protocol.disab /etc/dovecot/protocols.d/managesieved.protocol
	fi

	# Copy pipe and filter programs, if any
	rm -f /usr/lib/dovecot/sieve-filter/*
	rm -f /usr/lib/dovecot/sieve-pipe/*
	[ -d /tmp/docker-mailserver/sieve-filter ] && cp /tmp/docker-mailserver/sieve-filter/* /usr/lib/dovecot/sieve-filter/
	[ -d /tmp/docker-mailserver/sieve-pipe ] && cp /tmp/docker-mailserver/sieve-pipe/* /usr/lib/dovecot/sieve-pipe/
	if [ -f /tmp/docker-mailserver/before.dovecot.sieve ]; then
		sed -i "s/#sieve_before =/sieve_before =/" /etc/dovecot/conf.d/90-sieve.conf
		cp /tmp/docker-mailserver/before.dovecot.sieve /usr/lib/dovecot/sieve-global/
		sievec /usr/lib/dovecot/sieve-global/before.dovecot.sieve
	else
		sed -i "s/  sieve_before =/  #sieve_before =/" /etc/dovecot/conf.d/90-sieve.conf
	fi

	if [ -f /tmp/docker-mailserver/after.dovecot.sieve ]; then
		sed -i "s/#sieve_after =/sieve_after =/" /etc/dovecot/conf.d/90-sieve.conf
		cp /tmp/docker-mailserver/after.dovecot.sieve /usr/lib/dovecot/sieve-global/
		sievec /usr/lib/dovecot/sieve-global/after.dovecot.sieve
	else 
		sed -i "s/  sieve_after =/  #sieve_after =/" /etc/dovecot/conf.d/90-sieve.conf	
	fi
	chown docker:docker -R /usr/lib/dovecot/sieve*
	chmod 550 -R /usr/lib/dovecot/sieve*
}

function _setup_dovecot_local_user() {
	notify 'task' 'Setting up Dovecot Local User'
	echo -n > /etc/postfix/vmailbox
	echo -n > /etc/dovecot/userdb
	if [ -f /tmp/docker-mailserver/postfix-accounts.cf -a "$ENABLE_LDAP" != 1 ]; then
		notify 'inf' "Checking file line endings"
		sed -i 's/\r//g' /tmp/docker-mailserver/postfix-accounts.cf
		notify 'inf' "Regenerating postfix user list"
		echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox

		# Checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
		sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf

		chown dovecot:dovecot /etc/dovecot/userdb
		chmod 640 /etc/dovecot/userdb

		sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
		sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

		# Creating users
		# 'pass' is encrypted
		# comments and empty lines are ignored
		grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-accounts.cf | while IFS=$'|' read login pass
		do
			# Setting variables for better readability
			user=$(echo ${login} | cut -d @ -f1)
			domain=$(echo ${login} | cut -d @ -f2)
			# Let's go!
			notify 'inf' "user '${user}' for domain '${domain}' with password '********'"
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
		done
	else
		notify 'inf' "'config/docker-mailserver/postfix-accounts.cf' is not provided. No mail account created."
	fi

	if [[ ! $(grep '@' /tmp/docker-mailserver/postfix-accounts.cf | grep '|') ]]; then
		if [ $ENABLE_LDAP -eq 0 ]; then
			notify 'fatal' "Unless using LDAP, you need at least 1 email account to start Dovecot."
			defunc
		fi
	fi

}

function _setup_ldap() {
	notify 'task' 'Setting up Ldap'

	notify 'inf' 'Checking for custom configs'
	# cp config files if in place
	for i in 'users' 'groups' 'aliases' 'domains'; do
	    fpath="/tmp/docker-mailserver/ldap-${i}.cf"
	    if [ -f $fpath ]; then
		cp ${fpath} /etc/postfix/ldap-${i}.cf
	    fi
	done

	notify 'inf' 'Starting to override configs'
	for f in /etc/postfix/ldap-users.cf /etc/postfix/ldap-groups.cf /etc/postfix/ldap-aliases.cf /etc/postfix/ldap-domains.cf /etc/postfix/maps/sender_login_maps.ldap
	do
		[[ $f =~ ldap-user ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_USER}"
		[[ $f =~ ldap-group ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_GROUP}"
		[[ $f =~ ldap-aliases ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_ALIAS}"
		[[ $f =~ ldap-domains ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_DOMAIN}"
		configomat.sh "LDAP_" "${f}"
	done

	notify 'inf' "Configuring dovecot LDAP"

	declare -A _dovecot_ldap_mapping

	_dovecot_ldap_mapping["DOVECOT_BASE"]="${DOVECOT_BASE:="${LDAP_SEARCH_BASE}"}"
	_dovecot_ldap_mapping["DOVECOT_DN"]="${DOVECOT_DN:="${LDAP_BIND_DN}"}"
	_dovecot_ldap_mapping["DOVECOT_DNPASS"]="${DOVECOT_DNPASS:="${LDAP_BIND_PW}"}"
	_dovecot_ldap_mapping["DOVECOT_HOSTS"]="${DOVECOT_HOSTS:="${LDAP_SERVER_HOST}"}"
	# Not sure whether this can be the same or not
	# _dovecot_ldap_mapping["DOVECOT_PASS_FILTER"]="${DOVECOT_PASS_FILTER:="${LDAP_QUERY_FILTER_USER}"}"
	# _dovecot_ldap_mapping["DOVECOT_USER_FILTER"]="${DOVECOT_USER_FILTER:="${LDAP_QUERY_FILTER_USER}"}"

	for var in ${!_dovecot_ldap_mapping[@]}; do
		export $var=${_dovecot_ldap_mapping[$var]}
	done

	configomat.sh "DOVECOT_" "/etc/dovecot/dovecot-ldap.conf.ext"

	# Add  domainname to vhost.
	echo $DOMAINNAME >> /tmp/vhost.tmp

	notify 'inf' "Enabling dovecot LDAP authentification"
	sed -i -e '/\!include auth-ldap\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
	sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf

	notify 'inf' "Configuring LDAP"
	[ -f /etc/postfix/ldap-users.cf ] && \
		postconf -e "virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf" || \
		notify 'inf' "==> Warning: /etc/postfix/ldap-user.cf not found"

	[ -f /etc/postfix/ldap-domains.cf ] && \
		postconf -e "virtual_mailbox_domains = /etc/postfix/vhost, ldap:/etc/postfix/ldap-domains.cf" || \
		notify 'inf' "==> Warning: /etc/postfix/ldap-domains.cf not found"

	[ -f /etc/postfix/ldap-aliases.cf -a -f /etc/postfix/ldap-groups.cf ] && \
		postconf -e "virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf, ldap:/etc/postfix/ldap-groups.cf" || \
		notify 'inf' "==> Warning: /etc/postfix/ldap-aliases.cf or /etc/postfix/ldap-groups.cf not found"

	return 0
}

function _setup_postgrey() {
	notify 'inf' "Configuring postgrey"
	sed -i -e 's/, reject_rbl_client bl.spamcop.net$/, reject_rbl_client bl.spamcop.net, check_policy_service inet:127.0.0.1:10023/' /etc/postfix/main.cf
	sed -i -e "s/\"--inet=127.0.0.1:10023\"/\"--inet=127.0.0.1:10023 --delay=$POSTGREY_DELAY --max-age=$POSTGREY_MAX_AGE --auto-whitelist-clients=$POSTGREY_AUTO_WHITELIST_CLIENTS\"/" /etc/default/postgrey
	TEXT_FOUND=`grep -i "POSTGREY_TEXT" /etc/default/postgrey | wc -l`

	if [ $TEXT_FOUND -eq 0 ]; then
		printf "POSTGREY_TEXT=\"$POSTGREY_TEXT\"\n\n" >> /etc/default/postgrey
	fi
	if [ -f /tmp/docker-mailserver/whitelist_clients.local ]; then
		cp -f /tmp/docker-mailserver/whitelist_clients.local /etc/postgrey/whitelist_clients.local
	fi
	if [ -f /tmp/docker-mailserver/whitelist_recipients ]; then
		cp -f /tmp/docker-mailserver/whitelist_recipients /etc/postgrey/whitelist_recipients
	fi
}

function _setup_postfix_postscreen() {
	notify 'inf' "Configuring postscreen"
	sed -i -e "s/postscreen_dnsbl_action = enforce/postscreen_dnsbl_action = $POSTSCREEN_ACTION/" \
	       -e "s/postscreen_greet_action = enforce/postscreen_greet_action = $POSTSCREEN_ACTION/" \
	       -e "s/postscreen_bare_newline_action = enforce/postscreen_bare_newline_action = $POSTSCREEN_ACTION/" /etc/postfix/main.cf
}

function _setup_postfix_sizelimits() {
	notify 'inf' "Configuring postfix message size limit"
	postconf -e "message_size_limit = ${DEFAULT_VARS["POSTFIX_MESSAGE_SIZE_LIMIT"]}"
	notify 'inf' "Configuring postfix mailbox size limit"
	postconf -e "mailbox_size_limit = ${DEFAULT_VARS["POSTFIX_MAILBOX_SIZE_LIMIT"]}"
}

function _setup_postfix_smtputf8() {
        notify 'inf' "Configuring postfix smtputf8 support (disable)"
        postconf -e "smtputf8_enable = no"
}

function _setup_spoof_protection () {
	notify 'inf' "Configuring Spoof Protection"
	sed -i 's|smtpd_sender_restrictions =|smtpd_sender_restrictions = reject_authenticated_sender_login_mismatch,|' /etc/postfix/main.cf
	[ "$ENABLE_LDAP" = 1 ] \
		&& postconf -e "smtpd_sender_login_maps=ldap:/etc/postfix/ldap-users.cf ldap:/etc/postfix/ldap-aliases.cf ldap:/etc/postfix/ldap-groups.cf" \
		|| postconf -e "smtpd_sender_login_maps=texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/regexp, pcre:/etc/postfix/maps/sender_login_maps.pcre"
}

function _setup_postfix_access_control() {
  notify 'inf' "Configuring user access"
  [ -f /tmp/docker-mailserver/postfix-send-access.cf ] && sed -i 's|smtpd_sender_restrictions =|smtpd_sender_restrictions = check_sender_access texthash:/tmp/docker-mailserver/postfix-send-access.cf,|' /etc/postfix/main.cf
  [ -f /tmp/docker-mailserver/postfix-receive-access.cf ] && sed -i 's|smtpd_recipient_restrictions =|smtpd_recipient_restrictions = check_recipient_access texthash:/tmp/docker-mailserver/postfix-receive-access.cf,|' /etc/postfix/main.cf
}

function _setup_postfix_sasl() {
    if [[ ${ENABLE_SASLAUTHD} == 1 ]];then
	[ ! -f /etc/postfix/sasl/smtpd.conf ] && cat > /etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
mech_list: plain login
EOF
    fi

    # cyrus sasl or dovecot sasl
    if [[ ${ENABLE_SASLAUTHD} == 1 ]] || [[ ${SMTP_ONLY} == 0 ]];then
	sed -i -e 's|^smtpd_sasl_auth_enable[[:space:]]\+.*|smtpd_sasl_auth_enable = yes|g' /etc/postfix/main.cf
    else
	sed -i -e 's|^smtpd_sasl_auth_enable[[:space:]]\+.*|smtpd_sasl_auth_enable = no|g' /etc/postfix/main.cf
    fi

    return 0
}

function _setup_saslauthd() {
	notify 'task' "Setting up Saslauthd"

	notify 'inf' "Configuring Cyrus SASL"
	# checking env vars and setting defaults
	[ -z "$SASLAUTHD_MECHANISMS" ] && SASLAUTHD_MECHANISMS=pam
	[ "$SASLAUTHD_MECHANISMS" = ldap -a -z "$SASLAUTHD_LDAP_SEARCH_BASE" ] && SASLAUTHD_MECHANISMS=pam
	[ -z "$SASLAUTHD_LDAP_SERVER" ] && SASLAUTHD_LDAP_SERVER=localhost
	[ -z "$SASLAUTHD_LDAP_FILTER" ] && SASLAUTHD_LDAP_FILTER='(&(uniqueIdentifier=%u)(mailEnabled=TRUE))'
	([ -z "$SASLAUTHD_LDAP_SSL" ] || [ $SASLAUTHD_LDAP_SSL == 0 ]) && SASLAUTHD_LDAP_PROTO='ldap://' || SASLAUTHD_LDAP_PROTO='ldaps://'
	[ -z "$SASLAUTHD_LDAP_START_TLS" ] && SASLAUTHD_LDAP_START_TLS=no
	[ -z "$SASLAUTHD_LDAP_TLS_CHECK_PEER" ] && SASLAUTHD_LDAP_TLS_CHECK_PEER=no

	if [ ! -f /etc/saslauthd.conf ]; then
		notify 'inf' "Creating /etc/saslauthd.conf"
		cat > /etc/saslauthd.conf << EOF
ldap_servers: ${SASLAUTHD_LDAP_PROTO}${SASLAUTHD_LDAP_SERVER}

ldap_auth_method: bind
ldap_bind_dn: ${SASLAUTHD_LDAP_BIND_DN}
ldap_bind_pw: ${SASLAUTHD_LDAP_PASSWORD}

ldap_search_base: ${SASLAUTHD_LDAP_SEARCH_BASE}
ldap_filter: ${SASLAUTHD_LDAP_FILTER}

ldap_start_tls: $SASLAUTHD_LDAP_START_TLS
ldap_tls_check_peer: $SASLAUTHD_LDAP_TLS_CHECK_PEER

ldap_referrals: yes
log_level: 10
EOF
	fi

		 sed -i \
		 -e "/^[^#].*smtpd_sasl_type.*/s/^/#/g" \
		 -e "/^[^#].*smtpd_sasl_path.*/s/^/#/g" \
		 /etc/postfix/master.cf

	sed -i \
		-e "/smtpd_sasl_path =.*/d" \
		-e "/smtpd_sasl_type =.*/d" \
		-e "/dovecot_destination_recipient_limit =.*/d" \
		/etc/postfix/main.cf
	gpasswd -a postfix sasl
}

function _setup_postfix_aliases() {
	notify 'task' 'Setting up Postfix Aliases'

	echo -n > /etc/postfix/virtual
	echo -n > /etc/postfix/regexp
	if [ -f /tmp/docker-mailserver/postfix-virtual.cf ]; then
	# fixing old virtual user file
	  [[ $(grep ",$" /tmp/docker-mailserver/postfix-virtual.cf) ]] && sed -i -e "s/, /,/g" -e "s/,$//g" /tmp/docker-mailserver/postfix-virtual.cf
		# Copying virtual file
		cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual
		while read from to
		do
			# Setting variables for better readability
			uname=$(echo ${from} | cut -d @ -f1)
			domain=$(echo ${from} | cut -d @ -f2)
			# if they are equal it means the line looks like: "user1     other@domain.tld"
			test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
		done < /tmp/docker-mailserver/postfix-virtual.cf
	else
		notify 'inf' "Warning 'config/postfix-virtual.cf' is not provided. No mail alias/forward created."
	fi
	if [ -f /tmp/docker-mailserver/postfix-regexp.cf ]; then
		# Copying regexp alias file
		notify 'inf' "Adding regexp alias file postfix-regexp.cf"
		cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
		sed -i -e '/^virtual_alias_maps/{
		s/ pcre:.*//
		s/$/ pcre:\/etc\/postfix\/regexp/
		}' /etc/postfix/main.cf
	fi

	notify 'inf' "Configuring root alias"
	echo "root: ${POSTMASTER_ADDRESS}" > /etc/aliases
	if [ -f /tmp/docker-mailserver/postfix-aliases.cf ]; then
		cat /tmp/docker-mailserver/postfix-aliases.cf>>/etc/aliases
	else
		notify 'inf' "'config/postfix-aliases.cf' is not provided and will be auto created."
		echo -n >/tmp/docker-mailserver/postfix-aliases.cf
	fi
	postalias /etc/aliases
}

function _setup_SRS() {
	notify 'task' 'Setting up SRS'
	postconf -e "sender_canonical_maps = tcp:localhost:10001"
	postconf -e "sender_canonical_classes = envelope_sender"
	postconf -e "recipient_canonical_maps = tcp:localhost:10002"
	postconf -e "recipient_canonical_classes = envelope_recipient,header_recipient"
}

function _setup_dkim() {
	notify 'task' 'Setting up DKIM'

	mkdir -p /etc/opendkim && touch /etc/opendkim/SigningTable

	# Check if keys are already available
	if [ -e "/tmp/docker-mailserver/opendkim/KeyTable" ]; then
		cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/
		notify 'inf' "DKIM keys added for: `ls -C /etc/opendkim/keys/`"
		notify 'inf' "Changing permissions on /etc/opendkim"
		chown -R opendkim:opendkim /etc/opendkim/
		# And make sure permissions are right
		chmod -R 0700 /etc/opendkim/keys/
	else
		notify 'warn' "No DKIM key provided. Check the documentation to find how to get your keys."

		local _f_keytable="/etc/opendkim/KeyTable"
		[ ! -f "$_f_keytable" ] && touch "$_f_keytable"
	fi

	# Setup nameservers paramater from /etc/resolv.conf if not defined
	if ! grep '^Nameservers' /etc/opendkim.conf; then
		echo "Nameservers $(grep '^nameserver' /etc/resolv.conf | awk -F " " '{print $2}' | paste -sd ',' -)" >> /etc/opendkim.conf
		notify 'inf' "Nameservers added to /etc/opendkim.conf"
	fi
}

function _setup_ssl() {
	notify 'task' 'Setting up SSL'

  # TLS strength/level configuration
  case $TLS_LEVEL in
    "modern" )
      # Postfix configuration
      sed -i -r 's/^smtpd_tls_mandatory_protocols =.*$/smtpd_tls_mandatory_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1/' /etc/postfix/main.cf
      sed -i -r 's/^smtpd_tls_protocols =.*$/smtpd_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1/' /etc/postfix/main.cf
      sed -i -r 's/^smtp_tls_protocols =.*$/smtp_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1/' /etc/postfix/main.cf
      sed -i -r 's/^tls_high_cipherlist =.*$/tls_high_cipherlist = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256/' /etc/postfix/main.cf

      # Dovecot configuration (secure by default though)
      sed -i -r 's/^ssl_min_protocol =.*$/ssl_min_protocol = TLSv1.2/' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -r 's/^ssl_cipher_list =.*$/ssl_cipher_list = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256/' /etc/dovecot/conf.d/10-ssl.conf

      notify 'inf' "TLS configured with 'modern' ciphers"
    ;;
    "intermediate" )
      # Postfix configuration
      sed -i -r 's/^smtpd_tls_mandatory_protocols =.*$/smtpd_tls_mandatory_protocols = !SSLv2,!SSLv3/' /etc/postfix/main.cf
      sed -i -r 's/^smtpd_tls_protocols =.*$/smtpd_tls_protocols = !SSLv2,!SSLv3/' /etc/postfix/main.cf
      sed -i -r 's/^smtp_tls_protocols =.*$/smtp_tls_protocols = !SSLv2,!SSLv3/' /etc/postfix/main.cf
      sed -i -r 's/^tls_high_cipherlist =.*$/tls_high_cipherlist = ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS/' /etc/postfix/main.cf

      # Dovecot configuration
      sed -i -r 's/^ssl_min_protocol = .*$/ssl_min_protocol = TLSv1/' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -r 's/^ssl_cipher_list = .*$/ssl_cipher_list = ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS/' /etc/dovecot/conf.d/10-ssl.conf

      notify 'inf' "TLS configured with 'intermediate' ciphers"
    ;;
  esac

	# SSL certificate Configuration
	case $SSL_TYPE in
		"letsencrypt" )
			# letsencrypt folders and files mounted in /etc/letsencrypt
			if [ -e "/etc/letsencrypt/live/$HOSTNAME/fullchain.pem" ]; then
				KEY=""
				if [ -e "/etc/letsencrypt/live/$HOSTNAME/privkey.pem" ]; then
					KEY="privkey"
				elif [ -e "/etc/letsencrypt/live/$HOSTNAME/key.pem" ]; then
					KEY="key"
				else
					notify 'err' "Cannot access '/etc/letsencrypt/live/"$HOSTNAME"/privkey.pem' nor 'key.pem'"
				fi
				if [ -n "$KEY" ]; then
					notify 'inf' "Adding $HOSTNAME SSL certificate"

					# Postfix configuration
					sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/letsencrypt/live/'$HOSTNAME'/fullchain.pem~g' /etc/postfix/main.cf
					sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/letsencrypt/live/'$HOSTNAME'/'"$KEY"'\.pem~g' /etc/postfix/main.cf

					# Dovecot configuration
					sed -i -e 's~ssl_cert = </etc/dovecot/ssl/dovecot\.pem~ssl_cert = </etc/letsencrypt/live/'$HOSTNAME'/fullchain\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
					sed -i -e 's~ssl_key = </etc/dovecot/ssl/dovecot\.key~ssl_key = </etc/letsencrypt/live/'$HOSTNAME'/'"$KEY"'\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

					notify 'inf' "SSL configured with 'letsencrypt' certificates"
				else
					notify 'err' "Key filename not set!"
				fi
			else
				notify 'err' "Cannot access '/etc/letsencrypt/live/"$HOSTNAME"/fullchain.pem'"
			fi
		;;
	"custom" )
		# Adding CA signed SSL certificate if provided in 'postfix/ssl' folder
		if [ -e "/tmp/docker-mailserver/ssl/$HOSTNAME-full.pem" ]; then
			notify 'inf' "Adding $HOSTNAME SSL certificate"
			mkdir -p /etc/postfix/ssl
			cp "/tmp/docker-mailserver/ssl/$HOSTNAME-full.pem" /etc/postfix/ssl

			# Postfix configuration
			sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/'$HOSTNAME'-full.pem~g' /etc/postfix/main.cf
			sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/'$HOSTNAME'-full.pem~g' /etc/postfix/main.cf

			# Dovecot configuration
			sed -i -e 's~ssl_cert = </etc/dovecot/ssl/dovecot\.pem~ssl_cert = </etc/postfix/ssl/'$HOSTNAME'-full\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
			sed -i -e 's~ssl_key = </etc/dovecot/ssl/dovecot\.key~ssl_key = </etc/postfix/ssl/'$HOSTNAME'-full\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

			notify 'inf' "SSL configured with 'CA signed/custom' certificates"
		fi
		;;
	"manual" )
		# Lets you manually specify the location of the SSL Certs to use. This gives you some more control over this whole processes (like using kube-lego to generate certs)
		if [ -n "$SSL_CERT_PATH" ] \
		&& [ -n "$SSL_KEY_PATH" ]; then
			notify 'inf' "Configuring certificates using cert $SSL_CERT_PATH and key $SSL_KEY_PATH"
			mkdir -p /etc/postfix/ssl
			cp "$SSL_CERT_PATH" /etc/postfix/ssl/cert
			cp "$SSL_KEY_PATH" /etc/postfix/ssl/key
			chmod 600 /etc/postfix/ssl/cert
			chmod 600 /etc/postfix/ssl/key

			# Postfix configuration
			sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/cert~g' /etc/postfix/main.cf
			sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/key~g' /etc/postfix/main.cf

			# Dovecot configuration
			sed -i -e 's~ssl_cert = </etc/dovecot/ssl/dovecot\.pem~ssl_cert = </etc/postfix/ssl/cert~g' /etc/dovecot/conf.d/10-ssl.conf
			sed -i -e 's~ssl_key = </etc/dovecot/ssl/dovecot\.key~ssl_key = </etc/postfix/ssl/key~g' /etc/dovecot/conf.d/10-ssl.conf

			notify 'inf' "SSL configured with 'Manual' certificates"
		fi
	;;
"self-signed" )
	# Adding self-signed SSL certificate if provided in 'postfix/ssl' folder
	if [ -e "/tmp/docker-mailserver/ssl/$HOSTNAME-cert.pem" ] \
	&& [ -e "/tmp/docker-mailserver/ssl/$HOSTNAME-key.pem"  ] \
	&& [ -e "/tmp/docker-mailserver/ssl/$HOSTNAME-combined.pem" ] \
	&& [ -e "/tmp/docker-mailserver/ssl/demoCA/cacert.pem" ]; then
		notify 'inf' "Adding $HOSTNAME SSL certificate"
		mkdir -p /etc/postfix/ssl
		cp "/tmp/docker-mailserver/ssl/$HOSTNAME-cert.pem" /etc/postfix/ssl
		cp "/tmp/docker-mailserver/ssl/$HOSTNAME-key.pem" /etc/postfix/ssl
		# Force permission on key file
		chmod 600 /etc/postfix/ssl/$HOSTNAME-key.pem
		cp "/tmp/docker-mailserver/ssl/$HOSTNAME-combined.pem" /etc/postfix/ssl
		cp /tmp/docker-mailserver/ssl/demoCA/cacert.pem /etc/postfix/ssl

		# Postfix configuration
		sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/'$HOSTNAME'-cert.pem~g' /etc/postfix/main.cf
		sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/'$HOSTNAME'-key.pem~g' /etc/postfix/main.cf
		sed -i -r 's~#smtpd_tls_CAfile=~smtpd_tls_CAfile=/etc/postfix/ssl/cacert.pem~g' /etc/postfix/main.cf
		sed -i -r 's~#smtp_tls_CAfile=~smtp_tls_CAfile=/etc/postfix/ssl/cacert.pem~g' /etc/postfix/main.cf
		ln -s /etc/postfix/ssl/cacert.pem "/etc/ssl/certs/cacert-$HOSTNAME.pem"

		# Dovecot configuration
		sed -i -e 's~ssl_cert = </etc/dovecot/ssl/dovecot\.pem~ssl_cert = </etc/postfix/ssl/'$HOSTNAME'-combined\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
		sed -i -e 's~ssl_key = </etc/dovecot/ssl/dovecot\.key~ssl_key = </etc/postfix/ssl/'$HOSTNAME'-key\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

		notify 'inf' "SSL configured with 'self-signed' certificates"
	fi
	;;
    '' )
        # $SSL_TYPE=empty, no SSL certificate, plain text access

        # Dovecot configuration
        sed -i -e 's~#disable_plaintext_auth = yes~disable_plaintext_auth = no~g' /etc/dovecot/conf.d/10-auth.conf
        sed -i -e 's~ssl = required~ssl = yes~g' /etc/dovecot/conf.d/10-ssl.conf

        notify 'inf' "SSL configured with plain text access"
        ;;
    * )
        # Unknown option, default behavior, no action is required
        notify 'warn' "SSL configured by default"
        ;;
	esac
}

function _setup_postfix_vhost() {
	notify 'task' "Setting up Postfix vhost"

	if [ -f /tmp/vhost.tmp ]; then
		cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
	fi
}

function _setup_docker_permit() {
	notify 'task' 'Setting up PERMIT_DOCKER Option'

	container_ip=$(ip addr show eth0 | grep 'inet ' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1)
	container_network="$(echo $container_ip | cut -d '.' -f1-2).0.0"
	container_networks=$(ip -o -4 addr show type veth | egrep -o '[0-9\.]+/[0-9]+')

	case $PERMIT_DOCKER in
		"host" )
			notify 'inf' "Adding $container_network/16 to my networks"
			postconf -e "$(postconf | grep '^mynetworks =') $container_network/16"
			echo $container_network/16 >> /etc/opendmarc/ignore.hosts
			echo $container_network/16 >> /etc/opendkim/TrustedHosts
			;;

		"network" )
			notify 'inf' "Adding docker network in my networks"
			postconf -e "$(postconf | grep '^mynetworks =') 172.16.0.0/12"
			echo 172.16.0.0/12 >> /etc/opendmarc/ignore.hosts
			echo 172.16.0.0/12 >> /etc/opendkim/TrustedHosts
			;;
		"connected-networks" )
			for network in $container_networks; do
				network=$(_sanitize_ipv4_to_subnet_cidr $network)
				notify 'inf' "Adding docker network $network in my networks"
				postconf -e "$(postconf | grep '^mynetworks =') $network"
				echo $network >> /etc/opendmarc/ignore.hosts
				echo $network >> /etc/opendkim/TrustedHosts
			done
			;;
		* )
			notify 'inf' "Adding container ip in my networks"
			postconf -e "$(postconf | grep '^mynetworks =') $container_ip/32"
			echo $container_ip/32 >> /etc/opendmarc/ignore.hosts
			echo $container_ip/32 >> /etc/opendkim/TrustedHosts
			;;
	esac
}

function _setup_postfix_virtual_transport() {
	notify 'task' 'Setting up Postfix virtual transport'

	[ -z "${POSTFIX_DAGENT}" ] && \
		echo "${POSTFIX_DAGENT} not set." && \
		kill -15 `cat /var/run/supervisord.pid` && return 1
	postconf -e "virtual_transport = ${POSTFIX_DAGENT}"
}

function _setup_postfix_override_configuration() {
	notify 'task' 'Setting up Postfix Override configuration'

	if [ -f /tmp/docker-mailserver/postfix-main.cf ]; then
		while read line; do
		# all valid postfix options start with a lower case letter
		# http://www.postfix.org/postconf.5.html
		if [[ "$line" =~ ^[a-z] ]]; then
			postconf -e "$line"
		fi
		done < /tmp/docker-mailserver/postfix-main.cf
		notify 'inf' "Loaded 'config/postfix-main.cf'"
	else
		notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailserver/postfix-main.cf' not provided."
	fi
	if [ -f /tmp/docker-mailserver/postfix-master.cf ]; then
		while read line; do
		if [[ "$line" =~ ^[0-9a-z] ]]; then
			postconf -P "$line"
		fi
		done < /tmp/docker-mailserver/postfix-master.cf
		notify 'inf' "Loaded 'config/postfix-master.cf'"
	else
		notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailserver/postfix-master.cf' not provided."
	fi

    notify 'inf' "set the compatibility level to 2"
    postconf compatibility_level=2
}

function _setup_postfix_sasl_password() {
	notify 'task' 'Setting up Postfix SASL Password'

	# Support general SASL password
	rm -f /etc/postfix/sasl_passwd
	if [ ! -z "$SASL_PASSWD" ]; then
		echo "$SASL_PASSWD" >> /etc/postfix/sasl_passwd
	fi

	# Install SASL passwords
	if [ -f /etc/postfix/sasl_passwd ]; then
		chown root:root /etc/postfix/sasl_passwd
		chmod 0600 /etc/postfix/sasl_passwd
		notify 'inf' "Loaded SASL_PASSWD"
	else
		notify 'inf' "Warning: 'SASL_PASSWD' is not provided. /etc/postfix/sasl_passwd not created."
	fi
}

function _setup_postfix_default_relay_host() {
	notify 'task' 'Applying default relay host to Postfix'

	notify 'inf' "Applying default relay host $DEFAULT_RELAY_HOST to /etc/postfix/main.cf"
	postconf -e "relayhost = $DEFAULT_RELAY_HOST"
}

function _setup_postfix_relay_hosts() {
	notify 'task' 'Setting up Postfix Relay Hosts'
	# copy old AWS_SES variables to new variables
	if [ -z "$RELAY_HOST" ]; then
		if [ ! -z "$AWS_SES_HOST" ]; then
			notify 'inf' "Using deprecated AWS_SES environment variables"
			RELAY_HOST=$AWS_SES_HOST
		fi
	fi
	if [ -z "$RELAY_PORT" ]; then
		if [ -z "$AWS_SES_PORT" ]; then
			RELAY_PORT=25
		else
			RELAY_PORT=$AWS_SES_PORT
		fi
	fi
	if [ -z "$RELAY_USER" ]; then
		if [ ! -z "$AWS_SES_USERPASS" ]; then
			# NB this will fail if the password contains a colon!
			RELAY_USER=$(echo "$AWS_SES_USERPASS" | cut -f 1 -d ":")
			RELAY_PASSWORD=$(echo "$AWS_SES_USERPASS" | cut -f 2 -d ":")
		fi
	fi
	notify 'inf' "Setting up outgoing email relaying via $RELAY_HOST:$RELAY_PORT"

	# setup /etc/postfix/sasl_passwd
	# --
	# @domain1.com        postmaster@domain1.com:your-password-1
	# @domain2.com        postmaster@domain2.com:your-password-2
	# @domain3.com        postmaster@domain3.com:your-password-3
	#
	# [smtp.mailgun.org]:587  postmaster@domain2.com:your-password-2

	if [ -f /tmp/docker-mailserver/postfix-sasl-password.cf ]; then
		notify 'inf' "Adding relay authentication from postfix-sasl-password.cf"
		while read line; do
			if ! echo "$line" | grep -q -e "\s*#"; then
				echo "$line" >> /etc/postfix/sasl_passwd
			fi
		done < /tmp/docker-mailserver/postfix-sasl-password.cf
	fi

	# add default relay
	if [ ! -z "$RELAY_USER" ] && [ ! -z "$RELAY_PASSWORD" ]; then
		echo "[$RELAY_HOST]:$RELAY_PORT		$RELAY_USER:$RELAY_PASSWORD" >> /etc/postfix/sasl_passwd
	else
		if [ ! -f /tmp/docker-mailserver/postfix-sasl-password.cf ]; then
			notify 'warn' "No relay auth file found and no default set"
		fi
	fi

	if [ -f /etc/postfix/sasl_passwd ]; then
		chown root:root /etc/postfix/sasl_passwd
		chmod 0600 /etc/postfix/sasl_passwd
	fi
	# end /etc/postfix/sasl_passwd

	# setup /etc/postfix/relayhost_map
	# --
	# @domain1.com        [smtp.mailgun.org]:587
	# @domain2.com        [smtp.mailgun.org]:587
	# @domain3.com        [smtp.mailgun.org]:587

	echo -n > /etc/postfix/relayhost_map

	if [ -f /tmp/docker-mailserver/postfix-relaymap.cf ]; then
		notify 'inf' "Adding relay mappings from postfix-relaymap.cf"
		while read line; do
			if ! echo "$line" | grep -q -e "\s*#"; then
				echo "$line" >> /etc/postfix/relayhost_map
			fi
		done < /tmp/docker-mailserver/postfix-relaymap.cf
	fi
	grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-accounts.cf | while IFS=$'|' read login pass
	do
		domain=$(echo ${login} | cut -d @ -f2)
		if ! grep -q -e "^@${domain}\b" /etc/postfix/relayhost_map; then
			notify 'inf' "Adding relay mapping for ${domain}"
			echo "@${domain}		[$RELAY_HOST]:$RELAY_PORT" >> /etc/postfix/relayhost_map
		fi
	done
	# remove lines with no destination
	sed -i '/^@\S*\s*$/d' /etc/postfix/relayhost_map

	chown root:root /etc/postfix/relayhost_map
	chmod 0600 /etc/postfix/relayhost_map
	# end /etc/postfix/relayhost_map

	postconf -e \
		"smtp_sasl_auth_enable = yes" \
		"smtp_sasl_security_options = noanonymous" \
		"smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd" \
		"smtp_use_tls = yes" \
		"smtp_tls_security_level = encrypt" \
		"smtp_tls_note_starttls_offer = yes" \
		"smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt" \
		"sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map" \
		"smtp_sender_dependent_authentication = yes"
}

function _setup_postfix_dhparam() {
	notify 'task' 'Setting up Postfix dhparam'
	if [ "$ONE_DIR" = 1 ];then
		DHPARAMS_FILE=/var/mail-state/lib-shared/dhparams.pem
		if [ ! -f $DHPARAMS_FILE ]; then
			notify 'inf' "Generate new shared dhparams (postfix)"
			mkdir -p $(dirname "$DHPARAMS_FILE")
			openssl dhparam -out $DHPARAMS_FILE 2048
		else
			notify 'inf' "Use postfix dhparams that was generated previously"
		fi

		# Copy from the state directory to the working location
		rm -f /etc/postfix/dhparams.pem && cp $DHPARAMS_FILE /etc/postfix/dhparams.pem
	else
                if [ ! -f /etc/postfix/dhparams.pem ]; then
                        if [ -f /etc/dovecot/dh.pem ]; then
                                notify 'inf' "Copy dovecot dhparams to postfix"
                                cp /etc/dovecot/dh.pem /etc/postfix/dhparams.pem
                        elif [ -f /tmp/docker-mailserver/dhparams.pem ]; then
                                notify 'inf' "Copy pre-generated dhparams to postfix"
                                cp /tmp/docker-mailserver/dhparams.pem /etc/postfix/dhparams.pem
                        else
                                notify 'inf' "Generate new dhparams for postfix"
                                openssl dhparam -out /etc/postfix/dhparams.pem 2048
                        fi
                else
                        notify 'inf' "Use existing postfix dhparams"
                fi
	fi
}

function _setup_dovecot_dhparam() {
        notify 'task' 'Setting up Dovecot dhparam'
        if [ "$ONE_DIR" = 1 ];then
                DHPARAMS_FILE=/var/mail-state/lib-shared/dhparams.pem
                if [ ! -f $DHPARAMS_FILE ]; then
                        notify 'inf' "Generate new shared dhparams (dovecot)"
                        mkdir -p $(dirname "$DHPARAMS_FILE")
                        openssl dhparam -out $DHPARAMS_FILE 2048
                else
                        notify 'inf' "Use dovecot dhparams that was generated previously"
                fi

                # Copy from the state directory to the working location
                rm -f /etc/dovecot/dh.pem && cp $DHPARAMS_FILE /etc/dovecot/dh.pem
        else
                if [ ! -f /etc/dovecot/dh.pem ]; then
                        if [ -f /etc/postfix/dhparams.pem ]; then
                                notify 'inf' "Copy postfix dhparams to dovecot"
                                cp /etc/postfix/dhparams.pem /etc/dovecot/dh.pem
                        elif [ -f /tmp/docker-mailserver/dhparams.pem ]; then
                                notify 'inf' "Copy pre-generated dhparams to dovecot"
                                cp /tmp/docker-mailserver/dhparams.pem /etc/dovecot/dh.pem
                        else
                                notify 'inf' "Generate new dhparams for dovecot"
                                openssl dhparam -out /etc/dovecot/dh.pem 2048
                        fi
                else
                        notify 'inf' "Use existing dovecot dhparams"
                fi
        fi
}

function _setup_security_stack() {
	notify 'task' "Setting up Security Stack"

	# recreate auto-generated file
	dms_amavis_file="/etc/amavis/conf.d/61-dms_auto_generated"
  echo "# WARNING: this file is auto-generated." > $dms_amavis_file
	echo "use strict;" >> $dms_amavis_file

	# Spamassassin
	if [ "$ENABLE_SPAMASSASSIN" = 0 ]; then
		notify 'warn' "Spamassassin is disabled. You can enable it with 'ENABLE_SPAMASSASSIN=1'"
		echo "@bypass_spam_checks_maps = (1);" >> $dms_amavis_file
	elif [ "$ENABLE_SPAMASSASSIN" = 1 ]; then
		notify 'inf' "Enabling and configuring spamassassin"
		SA_TAG=${SA_TAG:="2.0"} && sed -i -r 's/^\$sa_tag_level_deflt (.*);/\$sa_tag_level_deflt = '$SA_TAG';/g' /etc/amavis/conf.d/20-debian_defaults
		SA_TAG2=${SA_TAG2:="6.31"} && sed -i -r 's/^\$sa_tag2_level_deflt (.*);/\$sa_tag2_level_deflt = '$SA_TAG2';/g' /etc/amavis/conf.d/20-debian_defaults
		SA_KILL=${SA_KILL:="6.31"} && sed -i -r 's/^\$sa_kill_level_deflt (.*);/\$sa_kill_level_deflt = '$SA_KILL';/g' /etc/amavis/conf.d/20-debian_defaults
		SA_SPAM_SUBJECT=${SA_SPAM_SUBJECT:="***SPAM*** "}
		if [ "$SA_SPAM_SUBJECT" == "undef" ]; then
			sed -i -r 's/^\$sa_spam_subject_tag (.*);/\$sa_spam_subject_tag = undef;/g' /etc/amavis/conf.d/20-debian_defaults
		else
			sed -i -r 's/^\$sa_spam_subject_tag (.*);/\$sa_spam_subject_tag = '"'$SA_SPAM_SUBJECT'"';/g' /etc/amavis/conf.d/20-debian_defaults
		fi
		test -e /tmp/docker-mailserver/spamassassin-rules.cf && cp /tmp/docker-mailserver/spamassassin-rules.cf /etc/spamassassin/
	fi

	# Clamav
	if [ "$ENABLE_CLAMAV" = 0 ]; then
		notify 'warn' "Clamav is disabled. You can enable it with 'ENABLE_CLAMAV=1'"
		echo "@bypass_virus_checks_maps = (1);" >> $dms_amavis_file
	elif [ "$ENABLE_CLAMAV" = 1 ]; then
		notify 'inf' "Enabling clamav"
	fi

	echo "1;  # ensure a defined return" >> $dms_amavis_file


	# Fail2ban
	if [ "$ENABLE_FAIL2BAN" = 1 ]; then
		notify 'inf' "Fail2ban enabled"
		test -e /tmp/docker-mailserver/fail2ban-fail2ban.cf && cp /tmp/docker-mailserver/fail2ban-fail2ban.cf /etc/fail2ban/fail2ban.local
		test -e /tmp/docker-mailserver/fail2ban-jail.cf && cp /tmp/docker-mailserver/fail2ban-jail.cf /etc/fail2ban/jail.local
	else
		# Disable logrotate config for fail2ban if not enabled
		rm -f /etc/logrotate.d/fail2ban
	fi

	# Fix cron.daily for spamassassin
	sed -i -e 's~invoke-rc.d spamassassin reload~/etc/init\.d/spamassassin reload~g' /etc/cron.daily/spamassassin

	# Copy user provided configuration files if provided
	if [ -f /tmp/docker-mailserver/amavis.cf ]; then
		cp /tmp/docker-mailserver/amavis.cf /etc/amavis/conf.d/50-user
	fi
}

function _setup_elk_forwarder() {
	notify 'task' 'Setting up Elk forwarder'

	ELK_PORT=${ELK_PORT:="5044"}
	ELK_HOST=${ELK_HOST:="elk"}
	notify 'inf' "Enabling log forwarding to ELK ($ELK_HOST:$ELK_PORT)"
	cat /etc/filebeat/filebeat.yml.tmpl \
		| sed "s@\$ELK_HOST@$ELK_HOST@g" \
		| sed "s@\$ELK_PORT@$ELK_PORT@g" \
		> /etc/filebeat/filebeat.yml
}

function _setup_logrotate() {
	notify 'inf' "Setting up logrotate"

	LOGROTATE="/var/log/mail/mail.log\n{\n  compress\n  copytruncate\n  delaycompress\n"
	case "$LOGROTATE_INTERVAL" in
		"daily" )
			notify 'inf' "Setting postfix logrotate interval to daily"
			LOGROTATE="$LOGROTATE  rotate 1\n  daily\n"
			;;
		"weekly" )
			notify 'inf' "Setting postfix logrotate interval to weekly"
			LOGROTATE="$LOGROTATE  rotate 1\n  weekly\n"
			;;
		"monthly" )
			notify 'inf' "Setting postfix logrotate interval to monthly"
			LOGROTATE="$LOGROTATE  rotate 1\n  monthly\n"
			;;
	esac
	LOGROTATE="$LOGROTATE}"
	echo -e "$LOGROTATE" > /etc/logrotate.d/maillog
}

function _setup_mail_summary() {
	notify 'inf' "Enable postfix summary with recipient $PFLOGSUMM_RECIPIENT"
        case "$PFLOGSUMM_TRIGGER" in
                "daily_cron" )
                        notify 'inf' "Creating daily cron job for pflogsumm report"
			echo "#!/bin/bash" > /etc/cron.daily/postfix-summary
			echo "/usr/local/bin/report-pflogsumm-yesterday $HOSTNAME $PFLOGSUMM_RECIPIENT $PFLOGSUMM_SENDER" \
			 >> /etc/cron.daily/postfix-summary
			chmod +x /etc/cron.daily/postfix-summary
                        ;;
                "logrotate" )
                        notify 'inf' "Add postrotate action for pflogsumm report"
			sed -i "s|}|  postrotate\n    /usr/local/bin/postfix-summary $HOSTNAME \
    $PFLOGSUMM_RECIPIENT $PFLOGSUMM_SENDER\n  endscript\n}\n|" /etc/logrotate.d/maillog
                        ;;
        esac
}

function _setup_logwatch() {
	notify 'inf' "Enable logwatch reports with recipient $LOGWATCH_RECIPIENT"
	case "$LOGWATCH_INTERVAL" in
		"daily" )
			notify 'inf' "Creating daily cron job for logwatch reports"
			echo "#!/bin/bash" > /etc/cron.daily/logwatch
			echo "/usr/sbin/logwatch --range Yesterday --hostname $HOSTNAME --mailto $LOGWATCH_RECIPIENT" \
			>> /etc/cron.daily/logwatch
			chmod 744 /etc/cron.daily/logwatch
			;;
		"weekly" )
			notify 'inf' "Creating weekly cron job for logwatch reports"
			echo "#!/bin/bash" > /etc/cron.weekly/logwatch
			echo "/usr/sbin/logwatch --range 'between -7 days and -1 days' --hostname $HOSTNAME --mailto $LOGWATCH_RECIPIENT" \
			>> /etc/cron.weekly/logwatch
			chmod 744 /etc/cron.weekly/logwatch
			;;
	esac
}

function _setup_environment() {
    notify 'task' 'Setting up /etc/environment'

    local banner="# docker environment"
    local var
    if ! grep -q "$banner" /etc/environment; then
        echo $banner >> /etc/environment
        for var in "VIRUSMAILS_DELETE_DELAY"; do
            echo "$var=${!var}" >> /etc/environment
        done
    fi
}

##########################################################################
# << Setup Stack
##########################################################################


##########################################################################
# >> Fix Stack
#
# Description: Place functions for temporary workarounds and fixes here
##########################################################################
function fix() {
	notify 'taskgrg' "Post-configuration checks..."
	for _func in "${FUNCS_FIX[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done

        notify 'taskgrg' "Remove leftover pid files from a stop/start"
        rm -rf /var/run/*.pid /var/run/*/*.pid

	touch /dev/shm/supervisor.sock
}

function _fix_var_mail_permissions() {
	notify 'task' 'Checking /var/mail permissions'

	# Fix permissions, but skip this if 3 levels deep the user id is already set
	if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
		notify 'inf' "Fixing /var/mail permissions"
		chown -R 5000:5000 /var/mail
	else
		notify 'inf' "Permissions in /var/mail look OK"
		return 0
	fi
}

function _fix_var_amavis_permissions() {
	if [[ "$ONE_DIR" -eq 0 ]]; then
		amavis_state_dir=/var/lib/amavis
	else
		amavis_state_dir=/var/mail-state/lib-amavis
	fi
	notify 'task' 'Checking $amavis_state_dir permissions'

	amavis_permissions_status=$(find -H $amavis_state_dir -maxdepth 3 -a \( \! -user amavis -o \! -group amavis \))

	if [ -n "$amavis_permissions_status" ]; then
		notify 'inf' "Fixing $amavis_state_dir permissions"
		chown -hR amavis:amavis $amavis_state_dir
	else
		notify 'inf' "Permissions in $amavis_state_dir look OK"
		return 0
	fi
}

function _fix_cleanup_clamav() {
    notify 'task' 'Cleaning up disabled Clamav'
    rm -f /etc/logrotate.d/clamav-*
    rm -f /etc/cron.d/clamav-freshclam
}

function _fix_cleanup_spamassassin() {
    notify 'task' 'Cleaning up disabled spamassassin'
    rm -f /etc/cron.daily/spamassassin
}

##########################################################################
# << Fix Stack
##########################################################################


##########################################################################
# >> Misc Stack
#
# Description: Place functions that do not fit in the sections above here
##########################################################################
function misc() {
	notify 'taskgrp' 'Starting Misc'

	for _func in "${FUNCS_MISC[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _misc_save_states() {
	# consolidate all states into a single directory (`/var/mail-state`) to allow persistence using docker volumes
	statedir=/var/mail-state
	if [ "$ONE_DIR" = 1 -a -d $statedir ]; then
		notify 'inf' "Consolidating all state onto $statedir"
		for d in /var/spool/postfix /var/lib/postfix /var/lib/amavis /var/lib/clamav /var/lib/spamassassin /var/lib/fail2ban /var/lib/postgrey /var/lib/dovecot; do
			dest=$statedir/`echo $d | sed -e 's/.var.//; s/\//-/g'`
			if [ -d $dest ]; then
				notify 'inf' "  Destination $dest exists, linking $d to it"
				rm -rf $d
				ln -s $dest $d
			elif [ -d $d ]; then
				notify 'inf' "  Moving contents of $d to $dest:" `ls $d`
				mv $d $dest
				ln -s $dest $d
			else
				notify 'inf' "  Linking $d to $dest"
				mkdir -p $dest
				ln -s $dest $d
			fi
		done

		notify 'inf' 'Fixing /var/mail-state/* permissions'
		chown -R clamav /var/mail-state/lib-clamav
		chown -R postfix /var/mail-state/lib-postfix
		chown -R postgrey /var/mail-state/lib-postgrey
		chown -R debian-spamd /var/mail-state/lib-spamassassin
		chown -R postfix /var/mail-state/spool-postfix

	fi
}

##########################################################################
# >> Start Daemons
##########################################################################
function start_daemons() {
	notify 'taskgrp' 'Starting mail server'

	for _func in "${DAEMONS_START[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _start_daemons_cron() {
	notify 'task' 'Starting cron' 'n'
	supervisorctl start cron
}

function _start_daemons_rsyslog() {
	notify 'task' 'Starting rsyslog ' 'n'
    supervisorctl start rsyslog
}

function _start_daemons_saslauthd() {
	notify 'task' 'Starting saslauthd' 'n'
    supervisorctl start "saslauthd_${SASLAUTHD_MECHANISMS}"
}

function _start_daemons_fail2ban() {
	notify 'task' 'Starting fail2ban ' 'n'
	touch /var/log/auth.log
	# Delete fail2ban.sock that probably was left here after container restart
	if [ -e /var/run/fail2ban/fail2ban.sock ]; then
		rm /var/run/fail2ban/fail2ban.sock
	fi
    supervisorctl start fail2ban
}

function _start_daemons_opendkim() {
	notify 'task' 'Starting opendkim ' 'n'
    supervisorctl start opendkim
}

function _start_daemons_opendmarc() {
	notify 'task' 'Starting opendmarc ' 'n'
    supervisorctl start opendmarc
}

function _start_daemons_postsrsd(){
	notify 'task' 'Starting postsrsd ' 'n'
	supervisorctl start postsrsd
}

function _start_daemons_postfix() {
	notify 'task' 'Starting postfix' 'n'
    supervisorctl start postfix
}

function _start_daemons_dovecot() {
	# Here we are starting sasl and imap, not pop3 because it's disabled by default

	notify 'task' 'Starting dovecot services' 'n'

	if [ "$ENABLE_POP3" = 1 ]; then
		notify 'task' 'Starting pop3 services' 'n'
		mv /etc/dovecot/protocols.d/pop3d.protocol.disab /etc/dovecot/protocols.d/pop3d.protocol
	fi

	if [ -f /tmp/docker-mailserver/dovecot.cf ]; then
		cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf
	fi

    supervisorctl start dovecot

	# @TODO fix: on integration test
	# doveadm: Error: userdb lookup: connect(/var/run/dovecot/auth-userdb) failed: No such file or directory
	# doveadm: Fatal: user listing failed

	#if [ "$ENABLE_LDAP" != 1 ]; then
		#echo "Listing users"
		#/usr/sbin/dovecot user '*'
	#fi
}

function _start_daemons_filebeat() {
	notify 'task' 'Starting filebeat' 'n'
    supervisorctl start filebeat
}

function _start_daemons_fetchmail() {
	notify 'task' 'Starting fetchmail' 'n'
	/usr/local/bin/setup-fetchmail
	supervisorctl start fetchmail
}

function _start_daemons_clamav() {
	notify 'task' 'Starting clamav' 'n'
    supervisorctl start clamav
}

function _start_daemons_postgrey() {
	notify 'task' 'Starting postgrey' 'n'
	rm -f /var/run/postgrey/postgrey.pid
    supervisorctl start postgrey
}


function _start_daemons_amavis() {
	notify 'task' 'Starting amavis' 'n'
    supervisorctl start amavis
}

##########################################################################
# << Start Daemons
##########################################################################


##########################################################################
# Start check for update postfix-accounts and postfix-virtual
##########################################################################

function _start_changedetector() {
	notify 'task' 'Starting changedetector' 'n'
    supervisorctl start changedetector
}


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# >>

. /usr/local/bin/helper_functions.sh

if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' "# ENV"
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' ""
printenv
fi

notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' "# docker-mailserver"
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' ""

register_functions

check
setup
fix
misc
start_daemons

notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "# $HOSTNAME is up and running"
notify 'taskgrp' "#"
notify 'taskgrp' ""

touch /var/log/mail/mail.log
tail -fn 0 /var/log/mail/mail.log


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# <<

exit 0
