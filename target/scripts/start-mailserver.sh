#! /bin/bash

##########################################################################
# >> SETUP DEFAULT VALUES
##########################################################################

DOVECOT_MAILBOX_FORMAT="${DOVECOT_MAILBOX_FORMAT:=maildir}"
DOVECOT_TLS="${DOVECOT_TLS:=no}"
ENABLE_CLAMAV="${ENABLE_CLAMAV:=0}"
ENABLE_FAIL2BAN="${ENABLE_FAIL2BAN:=0}"
ENABLE_FETCHMAIL="${ENABLE_FETCHMAIL:=0}"
ENABLE_LDAP="${ENABLE_LDAP:=0}"
ENABLE_MANAGESIEVE="${ENABLE_MANAGESIEVE:=0}"
ENABLE_POP3="${ENABLE_POP3:=0}"
ENABLE_POSTGREY="${ENABLE_POSTGREY:=0}"
ENABLE_QUOTAS="${ENABLE_QUOTAS:=1}"
ENABLE_SASLAUTHD="${ENABLE_SASLAUTHD:=0}"
ENABLE_SPAMASSASSIN="${ENABLE_SPAMASSASSIN:=0}"
ENABLE_SRS="${ENABLE_SRS:=0}"
FETCHMAIL_POLL="${FETCHMAIL_POLL:=300}"
FETCHMAIL_PARALLEL="${FETCHMAIL_PARALLEL:=0}"
LDAP_START_TLS="${LDAP_START_TLS:=no}"
LOGROTATE_INTERVAL="${LOGROTATE_INTERVAL:=${REPORT_INTERVAL:-daily}}"
LOGWATCH_INTERVAL="${LOGWATCH_INTERVAL:=none}"
MOVE_SPAM_TO_JUNK="${MOVE_SPAM_TO_JUNK:=1}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:=eth0}"
ONE_DIR="${ONE_DIR:=0}"
OVERRIDE_HOSTNAME="${OVERRIDE_HOSTNAME}"
POSTGREY_AUTO_WHITELIST_CLIENTS="${POSTGREY_AUTO_WHITELIST_CLIENTS:=5}"
POSTGREY_DELAY="${POSTGREY_DELAY:=300}"
POSTGREY_MAX_AGE="${POSTGREY_MAX_AGE:=35}"
POSTGREY_TEXT="${POSTGREY_TEXT:=Delayed by Postgrey}"
POSTFIX_INET_PROTOCOLS="${POSTFIX_INET_PROTOCOLS:=all}"
POSTFIX_MAILBOX_SIZE_LIMIT="${POSTFIX_MAILBOX_SIZE_LIMIT:=0}"         # no limit by default
POSTFIX_MESSAGE_SIZE_LIMIT="${POSTFIX_MESSAGE_SIZE_LIMIT:=10240000}"  # ~10 MB by default
POSTSCREEN_ACTION="${POSTSCREEN_ACTION:=enforce}"
REPORT_RECIPIENT="${REPORT_RECIPIENT:="0"}"
SMTP_ONLY="${SMTP_ONLY:=0}"
SPAMASSASSIN_SPAM_TO_INBOX_IS_SET="$( if [[ -n ${SPAMASSASSIN_SPAM_TO_INBOX+'set'} ]]; then echo true ; else echo false ; fi )"
SPAMASSASSIN_SPAM_TO_INBOX="${SPAMASSASSIN_SPAM_TO_INBOX:=0}"
SPOOF_PROTECTION="${SPOOF_PROTECTION:=0}"
SRS_SENDER_CLASSES="${SRS_SENDER_CLASSES:=envelope_sender}"
SSL_TYPE="${SSL_TYPE:=''}"
TLS_LEVEL="${TLS_LEVEL:=modern}"
VIRUSMAILS_DELETE_DELAY="${VIRUSMAILS_DELETE_DELAY:=7}"

##########################################################################
# >> GLOBAL VARIABLES
##########################################################################

HOSTNAME="$(hostname -f)"
DOMAINNAME="$(hostname -d)"
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum

##########################################################################
# >> REGISTER FUNCTIONS
#
# Add your new functions/methods here.
#
# NOTE: Position matters when registering a function in stacks.
#       First in First out
#
# Execution Logic:
#   > check functions
#   > setup functions
#   > fix functions
#   > misc functions
#   > start-daemons
#
# Example:
#
# if [[ CONDITION IS MET ]]
# then
#   _register_{setup,fix,check,start}_{functions,daemons} "${FUNCNAME}"
# fi
#
# Implement them in the section-group: {check, setup, fix, start}
#
##########################################################################

function register_functions
{
  _notify 'tasklog' 'Initializing setup'
  _notify 'task' 'Registering check, setup, fix, misc and start-daemons functions'

  ################### >> check funcs

  _register_check_function "_check_environment_variables"
  _register_check_function "_check_hostname"

  ################### >> setup funcs

  _register_setup_function "_setup_default_vars"
  _register_setup_function "_setup_file_permissions"

  if [[ ${SMTP_ONLY} -ne 1 ]]
  then
    _register_setup_function "_setup_dovecot"
    _register_setup_function "_setup_dovecot_dhparam"
    _register_setup_function "_setup_dovecot_quota"
    _register_setup_function "_setup_dovecot_local_user"
  fi

  [[ ${ENABLE_LDAP} -eq 1 ]] && _register_setup_function "_setup_ldap"
  [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && _register_setup_function "_setup_saslauthd"
  [[ ${ENABLE_POSTGREY} -eq 1 ]] && _register_setup_function "_setup_postgrey"

  _register_setup_function "_setup_dkim"
  _register_setup_function "_setup_ssl"

  [[ ${POSTFIX_INET_PROTOCOLS} != "all" ]] && _register_setup_function "_setup_inet_protocols"

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

  [[ ${SPOOF_PROTECTION} -eq 1 ]] && _register_setup_function "_setup_spoof_protection"

  if [[ ${ENABLE_SRS} -eq 1  ]]
  then
    _register_setup_function "_setup_SRS"
    _register_start_daemon "_start_daemons_postsrsd"
  fi

  _register_setup_function "_setup_postfix_access_control"

  [[ -n ${DEFAULT_RELAY_HOST:-''} ]] && _register_setup_function "_setup_postfix_default_relay_host"
  [[ -n ${RELAY_HOST:-''} ]] && _register_setup_function "_setup_postfix_relay_hosts"
  [[ ${ENABLE_POSTFIX_VIRTUAL_TRANSPORT:-0} -eq 1 ]] && _register_setup_function "_setup_postfix_virtual_transport"

  _register_setup_function "_setup_postfix_override_configuration"
  _register_setup_function "_setup_environment"
  _register_setup_function "_setup_logrotate"

  _register_setup_function "_setup_mail_summary"
  _register_setup_function "_setup_logwatch"

  _register_setup_function "_setup_user_patches"

  # compute last as the config files are modified in-place
  _register_setup_function "_setup_chksum_file"

  ################### >> fix funcs

  _register_fix_function "_fix_var_mail_permissions"
  _register_fix_function "_fix_var_amavis_permissions"

  [[ ${ENABLE_CLAMAV} -eq 0 ]] && _register_fix_function "_fix_cleanup_clamav"
  [[ ${ENABLE_SPAMASSASSIN} -eq 0 ]] &&	_register_fix_function "_fix_cleanup_spamassassin"

  ################### >> misc funcs

  _register_misc_function "_misc_save_states"

  ################### >> daemon funcs

  _register_start_daemon "_start_daemons_cron"
  _register_start_daemon "_start_daemons_rsyslog"

  [[ ${SMTP_ONLY} -ne 1 ]] && _register_start_daemon "_start_daemons_dovecot"

  # needs to be started before saslauthd
  _register_start_daemon "_start_daemons_opendkim"
  _register_start_daemon "_start_daemons_opendmarc"

  #postfix uses postgrey, needs to be started before postfix
  [[ ${ENABLE_POSTGREY} -eq 1 ]] &&	_register_start_daemon "_start_daemons_postgrey"

  _register_start_daemon "_start_daemons_postfix"

  [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && _register_start_daemon "_start_daemons_saslauthd"
  # care :: needs to run after postfix
  [[ ${ENABLE_FAIL2BAN} -eq 1 ]] &&	_register_start_daemon "_start_daemons_fail2ban"
  [[ ${ENABLE_FETCHMAIL} -eq 1 ]] && _register_start_daemon "_start_daemons_fetchmail"
  [[ ${ENABLE_CLAMAV} -eq 1 ]] &&	_register_start_daemon "_start_daemons_clamav"
  [[ ${ENABLE_LDAP} -eq 0 ]] && _register_start_daemon "_start_changedetector"

  _register_start_daemon "_start_daemons_amavis"
}

##########################################################################
# << REGISTER FUNCTIONS
##########################################################################


# ! ––––––––––––––––––––––––––––––––––––––––––––––
# ! ––– CARE – BEGIN –––––––––––––––––––––––––––––
# ! ––––––––––––––––––––––––––––––––––––––––––––––


##########################################################################
# >> CONSTANTS
##########################################################################

declare -a FUNCS_SETUP
declare -a FUNCS_FIX
declare -a FUNCS_CHECK
declare -a FUNCS_MISC
declare -a DAEMONS_START

##########################################################################
# << CONSTANTS
##########################################################################


##########################################################################
# >> protected register_functions
##########################################################################

function _register_start_daemon
{
  DAEMONS_START+=("${1}")
  _notify 'inf' "${1}() registered"
}

function _register_setup_function
{
  FUNCS_SETUP+=("${1}")
  _notify 'inf' "${1}() registered"
}

function _register_fix_function
{
  FUNCS_FIX+=("${1}")
  _notify 'inf' "${1}() registered"
}

function _register_check_function
{
  FUNCS_CHECK+=("${1}")
  _notify 'inf' "${1}() registered"
}

function _register_misc_function
{
  FUNCS_MISC+=("${1}")
  _notify 'inf' "${1}() registered"
}

##########################################################################
# << protected register_functions
##########################################################################

function _defunc
{
  _notify 'fatal' "Please fix your configuration. Exiting..."
  exit 1
}

function display_startup_daemon
{
  ${1} &>/dev/null
  local RES=${?}

  if [[ ${DMS_DEBUG} -eq 1 ]]
  then
    if [[ ${RES} -eq 0 ]]
    then
      _notify 'inf' " OK"
    else
      _notify 'err' " STARTUP FAILED"
    fi
  fi

  return "${RES}"
}

# ! ––––––––––––––––––––––––––––––––––––––––––––––
# ! ––– CARE – END –––––––––––––––––––––––––––––––
# ! ––––––––––––––––––––––––––––––––––––––––––––––


##########################################################################
# >> Check Stack
#
# Description: Place functions for initial check of container sanity
##########################################################################

function check
{
  _notify 'tasklog' 'Checking configuration'

  for FUNC in "${FUNCS_CHECK[@]}"
  do
    if ! ${FUNC}
    then
      _defunc
    fi
  done
}

function _check_hostname
{
  _notify "task" "Check that hostname/domainname is provided or overridden (no default docker hostname/kubernetes) [in ${FUNCNAME[0]}]"

  if [[ -n ${OVERRIDE_HOSTNAME} ]]
  then
    export HOSTNAME=${OVERRIDE_HOSTNAME}
    export DOMAINNAME="${HOSTNAME#*.}"
  fi

  _notify 'inf' "Domain has been set to ${DOMAINNAME}"
  _notify 'inf' "Hostname has been set to ${HOSTNAME}"

  if ( ! grep -E '^(\S+[.]\S+)$' <<< "${HOSTNAME}" >/dev/null )
  then
    _notify 'err' "Setting hostname/domainname is required"
    kill "$(< /var/run/supervisord.pid)" && return 1
  else
    return 0
  fi
}

function _check_environment_variables
{
  _notify "task" "Check that there are no conflicts with env variables [in ${FUNCNAME[0]}]"
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

function setup
{
  _notify 'tasklog' 'Configuring mail server'
  for FUNC in "${FUNCS_SETUP[@]}"
  do
    ${FUNC}
  done
}

function _setup_default_vars
{
  _notify 'task' "Setting up default variables"

  # update POSTMASTER_ADDRESS - must be done done after _check_hostname
  POSTMASTER_ADDRESS="${POSTMASTER_ADDRESS:="postmaster@${DOMAINNAME}"}"

  # update REPORT_SENDER - must be done done after _check_hostname
  REPORT_SENDER="${REPORT_SENDER:="mailserver-report@${HOSTNAME}"}"
  PFLOGSUMM_SENDER="${PFLOGSUMM_SENDER:=${REPORT_SENDER}}"

  # set PFLOGSUMM_TRIGGER here for backwards compatibility
  # when REPORT_RECIPIENT is on the old method should be used
  # ! needs to be a string comparison
  if [[ ${REPORT_RECIPIENT} == "0" ]]
  then
    PFLOGSUMM_TRIGGER="${PFLOGSUMM_TRIGGER:="none"}"
  else
    PFLOGSUMM_TRIGGER="${PFLOGSUMM_TRIGGER:="logrotate"}"
  fi

  # expand address to simplify the rest of the script
  if [[ ${REPORT_RECIPIENT} == "0" ]] || [[ ${REPORT_RECIPIENT} == "0" ]]
  then
    REPORT_RECIPIENT="${POSTMASTER_ADDRESS}"
    REPORT_RECIPIENT="${REPORT_RECIPIENT}"
  fi

  PFLOGSUMM_RECIPIENT="${PFLOGSUMM_RECIPIENT:=${REPORT_RECIPIENT}}"
  LOGWATCH_RECIPIENT="${LOGWATCH_RECIPIENT:=${REPORT_RECIPIENT}}"

  {
    echo "DOVECOT_MAILBOX_FORMAT=${DOVECOT_MAILBOX_FORMAT}"
    echo "DOVECOT_TLS=${DOVECOT_TLS}"
    echo "ENABLE_CLAMAV=${ENABLE_CLAMAV}"
    echo "ENABLE_FAIL2BAN=${ENABLE_FAIL2BAN}"
    echo "ENABLE_FETCHMAIL=${ENABLE_FETCHMAIL}"
    echo "ENABLE_LDAP=${ENABLE_LDAP}"
    echo "ENABLE_MANAGESIEVE=${ENABLE_MANAGESIEVE}"
    echo "ENABLE_POP3=${ENABLE_POP3}"
    echo "ENABLE_POSTGREY=${ENABLE_POSTGREY}"
    echo "ENABLE_QUOTAS=${ENABLE_QUOTAS}"
    echo "ENABLE_SASLAUTHD=${ENABLE_SASLAUTHD}"
    echo "ENABLE_SPAMASSASSIN=${ENABLE_SPAMASSASSIN}"
    echo "ENABLE_SRS=${ENABLE_SRS}"
    echo "FETCHMAIL_POLL=${FETCHMAIL_POLL}"
    echo "FETCHMAIL_PARALLEL=${FETCHMAIL_PARALLEL}"
    echo "LDAP_START_TLS=${LDAP_START_TLS}"
    echo "LOGROTATE_INTERVAL=${LOGROTATE_INTERVAL}"
    echo "LOGWATCH_INTERVAL=${LOGWATCH_INTERVAL}"
    echo "MOVE_SPAM_TO_JUNK=${MOVE_SPAM_TO_JUNK}"
    echo "NETWORK_INTERFACE=${NETWORK_INTERFACE}"
    echo "ONE_DIR=${ONE_DIR}"
    echo "OVERRIDE_HOSTNAME=${OVERRIDE_HOSTNAME}"
    echo "POSTGREY_AUTO_WHITELIST_CLIENTS=${POSTGREY_AUTO_WHITELIST_CLIENTS}"
    echo "POSTGREY_DELAY=${POSTGREY_DELAY}"
    echo "POSTGREY_MAX_AGE=${POSTGREY_MAX_AGE}"
    echo "POSTGREY_TEXT=${POSTGREY_TEXT}"
    echo "POSTFIX_INET_PROTOCOLS=${POSTFIX_INET_PROTOCOLS}"
    echo "POSTFIX_MAILBOX_SIZE_LIMIT=${POSTFIX_MAILBOX_SIZE_LIMIT}"
    echo "POSTFIX_MESSAGE_SIZE_LIMIT=${POSTFIX_MESSAGE_SIZE_LIMIT}"
    echo "POSTSCREEN_ACTION=${POSTSCREEN_ACTION}"
    echo "REPORT_RECIPIENT=${REPORT_RECIPIENT}"
    echo "SMTP_ONLY=${SMTP_ONLY}"
    echo "SPAMASSASSIN_SPAM_TO_INBOX=${SPAMASSASSIN_SPAM_TO_INBOX}"
    echo "SPOOF_PROTECTION=${SPOOF_PROTECTION}"
    echo "SRS_SENDER_CLASSES=${SRS_SENDER_CLASSES}"
    echo "SSL_TYPE=${SSL_TYPE}"
    echo "TLS_LEVEL=${TLS_LEVEL}"
    echo "VIRUSMAILS_DELETE_DELAY=${VIRUSMAILS_DELETE_DELAY}"
    echo "DMS_DEBUG=${DMS_DEBUG}"
  } >>/root/.bashrc
}

# File/folder permissions are fine when using docker volumes, but may be wrong
# when file system folders are mounted into the container.
# Set the expected values and create missing folders/files just in case.
function _setup_file_permissions
{
  _notify 'task' "Setting file/folder permissions"

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

function _setup_chksum_file
{
  _notify 'task' "Setting up configuration checksum file"

  if [[ -d /tmp/docker-mailserver ]]
  then
    _notify 'inf' "Creating ${CHKSUM_FILE}"
    _monitored_files_checksums >"${CHKSUM_FILE}"
  else
    # We could just skip the file, but perhaps config can be added later?
    # If so it must be processed by the check for changes script
    _notify 'inf' "Creating empty ${CHKSUM_FILE} (no config)"
    touch "${CHKSUM_FILE}"
  fi
}

function _setup_mailname
{
  _notify 'task' 'Setting up Mailname'

  _notify 'inf' "Creating /etc/mailname"
  echo "${DOMAINNAME}" > /etc/mailname
}

function _setup_amavis
{
  _notify 'task' 'Setting up Amavis'

  _notify 'inf' "Applying hostname to /etc/amavis/conf.d/05-node_id"
  # shellcheck disable=SC2016
  sed -i 's/^#\$myhostname = "mail.example.com";/\$myhostname = "'"${HOSTNAME}"'";/' /etc/amavis/conf.d/05-node_id
}

function _setup_dmarc_hostname
{
  _notify 'task' 'Setting up dmarc'

  _notify 'inf' "Applying hostname to /etc/opendmarc.conf"
  sed -i -e 's/^AuthservID.*$/AuthservID          '"${HOSTNAME}"'/g' \
    -e 's/^TrustedAuthservIDs.*$/TrustedAuthservIDs  '"${HOSTNAME}"'/g' /etc/opendmarc.conf
}

function _setup_postfix_hostname
{
  _notify 'task' 'Applying hostname and domainname to Postfix'

  _notify 'inf' "Applying hostname to /etc/postfix/main.cf"
  postconf -e "myhostname = ${HOSTNAME}"
  postconf -e "mydomain = ${DOMAINNAME}"
}

function _setup_dovecot_hostname
{
  _notify 'task' 'Applying hostname to Dovecot'

  _notify 'inf' "Applying hostname to /etc/dovecot/conf.d/15-lda.conf"
  sed -i 's/^#hostname =.*$/hostname = '"${HOSTNAME}"'/g' /etc/dovecot/conf.d/15-lda.conf
}

function _setup_dovecot
{
  _notify 'task' 'Setting up Dovecot'

  # moved from docker file, copy or generate default self-signed cert
  if [[ -f /var/mail-state/lib-dovecot/dovecot.pem ]] && [[ ${ONE_DIR} -eq 1 ]]
  then
    _notify 'inf' "Copying default dovecot cert"
    cp /var/mail-state/lib-dovecot/dovecot.key /etc/dovecot/ssl/
    cp /var/mail-state/lib-dovecot/dovecot.pem /etc/dovecot/ssl/
  fi

  if [[ ! -f /etc/dovecot/ssl/dovecot.pem ]]
  then
    _notify 'inf' "Generating default dovecot cert"

    pushd /usr/share/dovecot || return 1
    ./mkcert.sh
    popd || return 1

    if [[ ${ONE_DIR} -eq 1 ]]
    then
      mkdir -p /var/mail-state/lib-dovecot
      cp /etc/dovecot/ssl/dovecot.key /var/mail-state/lib-dovecot/
      cp /etc/dovecot/ssl/dovecot.pem /var/mail-state/lib-dovecot/
    fi
  fi

  cp -a /usr/share/dovecot/protocols.d /etc/dovecot/
  # disable pop3 (it will be eventually enabled later in the script, if requested)
  mv /etc/dovecot/protocols.d/pop3d.protocol /etc/dovecot/protocols.d/pop3d.protocol.disab
  mv /etc/dovecot/protocols.d/managesieved.protocol /etc/dovecot/protocols.d/managesieved.protocol.disab
  sed -i -e 's/#ssl = yes/ssl = yes/g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's/#port = 993/port = 993/g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's/#port = 995/port = 995/g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's/#ssl = yes/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf
  sed -i 's/^postmaster_address = .*$/postmaster_address = '"${POSTMASTER_ADDRESS}"'/g' /etc/dovecot/conf.d/15-lda.conf

  # set mail_location according to mailbox format
  case "${DOVECOT_MAILBOX_FORMAT}" in
    sdbox|mdbox )
      _notify 'inf' "Dovecot ${DOVECOT_MAILBOX_FORMAT} format configured"
      sed -i -e 's/^mail_location = .*$/mail_location = '"${DOVECOT_MAILBOX_FORMAT}"':\/var\/mail\/%d\/%n/g' /etc/dovecot/conf.d/10-mail.conf

      _notify 'inf' "Enabling cron job for dbox purge"
      mv /etc/cron.d/dovecot-purge.disabled /etc/cron.d/dovecot-purge
      chmod 644 /etc/cron.d/dovecot-purge
      ;;
    * )
      _notify 'inf' "Dovecot maildir format configured (default)"
      sed -i -e 's/^mail_location = .*$/mail_location = maildir:\/var\/mail\/%d\/%n/g' /etc/dovecot/conf.d/10-mail.conf
      ;;
  esac

  # enable Managesieve service by setting the symlink
  # to the configuration file Dovecot will actually find
  if [[ ${ENABLE_MANAGESIEVE} -eq 1 ]]
  then
    _notify 'inf' "Sieve management enabled"
    mv /etc/dovecot/protocols.d/managesieved.protocol.disab /etc/dovecot/protocols.d/managesieved.protocol
  fi

  # copy pipe and filter programs, if any
  rm -f /usr/lib/dovecot/sieve-filter/*
  rm -f /usr/lib/dovecot/sieve-pipe/*
  [[ -d /tmp/docker-mailserver/sieve-filter ]] && cp /tmp/docker-mailserver/sieve-filter/* /usr/lib/dovecot/sieve-filter/
  [[ -d /tmp/docker-mailserver/sieve-pipe ]] && cp /tmp/docker-mailserver/sieve-pipe/* /usr/lib/dovecot/sieve-pipe/

  # create global sieve directories
  mkdir -p /usr/lib/dovecot/sieve-global/before
  mkdir -p /usr/lib/dovecot/sieve-global/after

  if [[ -f /tmp/docker-mailserver/before.dovecot.sieve ]]
  then
    cp /tmp/docker-mailserver/before.dovecot.sieve /usr/lib/dovecot/sieve-global/before/50-before.dovecot.sieve
    sievec /usr/lib/dovecot/sieve-global/before/50-before.dovecot.sieve
  else
    rm -f /usr/lib/dovecot/sieve-global/before/50-before.dovecot.sieve /usr/lib/dovecot/sieve-global/before/50-before.dovecot.svbin
  fi

  if [[ -f /tmp/docker-mailserver/after.dovecot.sieve ]]
  then
    cp /tmp/docker-mailserver/after.dovecot.sieve /usr/lib/dovecot/sieve-global/after/50-after.dovecot.sieve
    sievec /usr/lib/dovecot/sieve-global/after/50-after.dovecot.sieve
  else
    rm -f /usr/lib/dovecot/sieve-global/after/50-after.dovecot.sieve /usr/lib/dovecot/sieve-global/after/50-after.dovecot.svbin
  fi

  # sieve will move spams to .Junk folder when SPAMASSASSIN_SPAM_TO_INBOX=1 and MOVE_SPAM_TO_JUNK=1
  if [[ ${SPAMASSASSIN_SPAM_TO_INBOX} -eq 1 ]] && [[ ${MOVE_SPAM_TO_JUNK} -eq 1 ]]
  then
    _notify 'inf' "Spam messages will be moved to the Junk folder."
    cp /etc/dovecot/sieve/before/60-spam.sieve /usr/lib/dovecot/sieve-global/before/
    sievec /usr/lib/dovecot/sieve-global/before/60-spam.sieve
  else
    rm -f /usr/lib/dovecot/sieve-global/before/60-spam.sieve /usr/lib/dovecot/sieve-global/before/60-spam.svbin
  fi

  chown docker:docker -R /usr/lib/dovecot/sieve*
  chmod 550 -R /usr/lib/dovecot/sieve*
  chmod -f +x /usr/lib/dovecot/sieve-pipe/*
}

function _setup_dovecot_quota
{
    _notify 'task' 'Setting up Dovecot quota'

    # Dovecot quota is disabled when using LDAP or SMTP_ONLY or when explicitly disabled.
    if [[ ${ENABLE_LDAP} -eq 1 ]] || [[ ${SMTP_ONLY} -eq 1 ]] || [[ ${ENABLE_QUOTAS} -eq 0 ]]
    then
      # disable dovecot quota in docevot confs
      if [[ -f /etc/dovecot/conf.d/90-quota.conf ]]
      then
        mv /etc/dovecot/conf.d/90-quota.conf /etc/dovecot/conf.d/90-quota.conf.disab
        sed -i "s/mail_plugins = \$mail_plugins quota/mail_plugins = \$mail_plugins/g" /etc/dovecot/conf.d/10-mail.conf
        sed -i "s/mail_plugins = \$mail_plugins imap_quota/mail_plugins = \$mail_plugins/g" /etc/dovecot/conf.d/20-imap.conf
      fi

      # disable quota policy check in postfix
      sed -i "s/check_policy_service inet:localhost:65265//g" /etc/postfix/main.cf
    else
      if [[ -f /etc/dovecot/conf.d/90-quota.conf.disab ]]
      then
        mv /etc/dovecot/conf.d/90-quota.conf.disab /etc/dovecot/conf.d/90-quota.conf
        sed -i "s/mail_plugins = \$mail_plugins/mail_plugins = \$mail_plugins quota/g" /etc/dovecot/conf.d/10-mail.conf
        sed -i "s/mail_plugins = \$mail_plugin/mail_plugins = \$mail_plugins imap_quota/g" /etc/dovecot/conf.d/20-imap.conf
      fi

      local MESSAGE_SIZE_LIMIT_MB=$((POSTFIX_MESSAGE_SIZE_LIMIT / 1000000))
      local MAILBOX_LIMIT_MB=$((POSTFIX_MAILBOX_SIZE_LIMIT / 1000000))

      sed -i "s/quota_max_mail_size =.*/quota_max_mail_size = ${MESSAGE_SIZE_LIMIT_MB}$([[ ${MESSAGE_SIZE_LIMIT_MB} -eq 0 ]] && echo "" || echo "M")/g" /etc/dovecot/conf.d/90-quota.conf
      sed -i "s/quota_rule = \*:storage=.*/quota_rule = *:storage=${MAILBOX_LIMIT_MB}$([[ ${MAILBOX_LIMIT_MB} -eq 0 ]] && echo "" || echo "M")/g" /etc/dovecot/conf.d/90-quota.conf

      if [[ ! -f /tmp/docker-mailserver/dovecot-quotas.cf ]]
      then
        _notify 'inf' "'config/docker-mailserver/dovecot-quotas.cf' is not provided. Using default quotas."
        : >/tmp/docker-mailserver/dovecot-quotas.cf
      fi

      # enable quota policy check in postfix
      sed -i "s/reject_unknown_recipient_domain, reject_rbl_client zen.spamhaus.org/reject_unknown_recipient_domain, check_policy_service inet:localhost:65265, reject_rbl_client zen.spamhaus.org/g" /etc/postfix/main.cf
    fi
}

function _setup_dovecot_local_user
{
  _notify 'task' 'Setting up Dovecot Local User'
  : >/etc/postfix/vmailbox
  : >/etc/dovecot/userdb

  if [[ -f /tmp/docker-mailserver/postfix-accounts.cf ]] && [[ ${ENABLE_LDAP} -ne 1 ]]
  then
    _notify 'inf' "Checking file line endings"
    sed -i 's/\r//g' /tmp/docker-mailserver/postfix-accounts.cf

    _notify 'inf' "Regenerating postfix user list"
    echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox

    # checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
    # shellcheck disable=SC1003
    sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf

    chown dovecot:dovecot /etc/dovecot/userdb
    chmod 640 /etc/dovecot/userdb

    sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
    sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

    # creating users ; 'pass' is encrypted
    # comments and empty lines are ignored
    while IFS=$'|' read -r LOGIN PASS
    do
      # Setting variables for better readability
      USER=$(echo "${LOGIN}" | cut -d @ -f1)
      DOMAIN=$(echo "${LOGIN}" | cut -d @ -f2)

      USER_ATTRIBUTES=""
      # test if user has a defined quota
      if [[ -f /tmp/docker-mailserver/dovecot-quotas.cf ]]
      then
        declare -a USER_QUOTA
        IFS=':' ; read -r -a USER_QUOTA < <(grep "${USER}@${DOMAIN}:" -i /tmp/docker-mailserver/dovecot-quotas.cf)
        unset IFS

        [[ ${#USER_QUOTA[@]} -eq 2 ]] && USER_ATTRIBUTES="${USER_ATTRIBUTES}userdb_quota_rule=*:bytes=${USER_QUOTA[1]}"
      fi

      # Let's go!
      _notify 'inf' "user '${USER}' for domain '${DOMAIN}' with password '********', attr=${USER_ATTRIBUTES}"

      echo "${LOGIN} ${DOMAIN}/${USER}/" >> /etc/postfix/vmailbox
      # User database for dovecot has the following format:
      # user:password:uid:gid:(gecos):home:(shell):extra_fields
      # Example :
      # ${LOGIN}:${PASS}:5000:5000::/var/mail/${DOMAIN}/${USER}::userdb_mail=maildir:/var/mail/${DOMAIN}/${USER}
      echo "${LOGIN}:${PASS}:5000:5000::/var/mail/${DOMAIN}/${USER}::${USER_ATTRIBUTES}" >> /etc/dovecot/userdb
      mkdir -p "/var/mail/${DOMAIN}/${USER}"

      # Copy user provided sieve file, if present
      if [[ -e "/tmp/docker-mailserver/${LOGIN}.dovecot.sieve" ]]
      then
        cp "/tmp/docker-mailserver/${LOGIN}.dovecot.sieve" "/var/mail/${DOMAIN}/${USER}/.dovecot.sieve"
      fi

      echo "${DOMAIN}" >> /tmp/vhost.tmp
    done < <(grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-accounts.cf)
  else
    _notify 'inf' "'config/docker-mailserver/postfix-accounts.cf' is not provided. No mail account created."
  fi

  if ! grep '@' /tmp/docker-mailserver/postfix-accounts.cf | grep -q '|'
  then
    if [[ ${ENABLE_LDAP} -eq 0 ]]
    then
      _notify 'fatal' "Unless using LDAP, you need at least 1 email account to start Dovecot."
      _defunc
    fi
  fi
}

function _setup_ldap
{
  _notify 'task' 'Setting up Ldap'
  _notify 'inf' 'Checking for custom configs'

  for i in 'users' 'groups' 'aliases' 'domains'
  do
    local FPATH="/tmp/docker-mailserver/ldap-${i}.cf"
    if [[ -f ${FPATH} ]]
    then
      cp "${FPATH}" "/etc/postfix/ldap-${i}.cf"
    fi
  done

  _notify 'inf' 'Starting to override configs'

  local FILES=(
    /etc/postfix/ldap-users.cf
    /etc/postfix/ldap-groups.cf
    /etc/postfix/ldap-aliases.cf
    /etc/postfix/ldap-domains.cf
    /etc/postfix/maps/sender_login_maps.ldap
  )

  for FILE in "${FILES[@]}"
  do
    [[ ${FILE} =~ ldap-user ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_USER}"
    [[ ${FILE} =~ ldap-group ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_GROUP}"
    [[ ${FILE} =~ ldap-aliases ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_ALIAS}"
    [[ ${FILE} =~ ldap-domains ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_DOMAIN}"
    configomat.sh "LDAP_" "${FILE}"
  done

  _notify 'inf' "Configuring dovecot LDAP"

  declare -A _dovecot_ldap_mapping

  _dovecot_ldap_mapping["DOVECOT_BASE"]="${DOVECOT_BASE:="${LDAP_SEARCH_BASE}"}"
  _dovecot_ldap_mapping["DOVECOT_DN"]="${DOVECOT_DN:="${LDAP_BIND_DN}"}"
  _dovecot_ldap_mapping["DOVECOT_DNPASS"]="${DOVECOT_DNPASS:="${LDAP_BIND_PW}"}"
  _dovecot_ldap_mapping["DOVECOT_HOSTS"]="${DOVECOT_HOSTS:="${LDAP_SERVER_HOST}"}"
  # Not sure whether this can be the same or not
  # _dovecot_ldap_mapping["DOVECOT_PASS_FILTER"]="${DOVECOT_PASS_FILTER:="${LDAP_QUERY_FILTER_USER}"}"
  # _dovecot_ldap_mapping["DOVECOT_USER_FILTER"]="${DOVECOT_USER_FILTER:="${LDAP_QUERY_FILTER_USER}"}"

  for VAR in "${!_dovecot_ldap_mapping[@]}"
  do
    export "${VAR}=${_dovecot_ldap_mapping[${VAR}]}"
  done

  configomat.sh "DOVECOT_" "/etc/dovecot/dovecot-ldap.conf.ext"

  # add domainname to vhost
  echo "${DOMAINNAME}" >>/tmp/vhost.tmp

  _notify 'inf' "Enabling dovecot LDAP authentification"

  sed -i -e '/\!include auth-ldap\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf

  _notify 'inf' "Configuring LDAP"

  if [[ -f /etc/postfix/ldap-users.cf ]]
  then
    postconf -e "virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf" || \
    _notify 'inf' "==> Warning: /etc/postfix/ldap-user.cf not found"
  fi

  if [[ -f /etc/postfix/ldap-domains.cf ]]
  then
    postconf -e "virtual_mailbox_domains = /etc/postfix/vhost, ldap:/etc/postfix/ldap-domains.cf" || \
    _notify 'inf' "==> Warning: /etc/postfix/ldap-domains.cf not found"
  fi

  if [[ -f /etc/postfix/ldap-aliases.cf ]] && [[ -f /etc/postfix/ldap-groups.cf ]]
  then
    postconf -e "virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf, ldap:/etc/postfix/ldap-groups.cf" || \
    _notify 'inf' "==> Warning: /etc/postfix/ldap-aliases.cf or /etc/postfix/ldap-groups.cf not found"
  fi

  return 0
}

function _setup_postgrey
{
  _notify 'inf' "Configuring postgrey"

  sed -i -e 's/, reject_rbl_client bl.spamcop.net$/, reject_rbl_client bl.spamcop.net, check_policy_service inet:127.0.0.1:10023/' /etc/postfix/main.cf
  sed -i -e "s/\"--inet=127.0.0.1:10023\"/\"--inet=127.0.0.1:10023 --delay=${POSTGREY_DELAY} --max-age=${POSTGREY_MAX_AGE} --auto-whitelist-clients=${POSTGREY_AUTO_WHITELIST_CLIENTS}\"/" /etc/default/postgrey

  TEXT_FOUND=$(grep -c -i "POSTGREY_TEXT" /etc/default/postgrey)

  if [[ ${TEXT_FOUND} -eq 0 ]]
  then
    printf "POSTGREY_TEXT=\"%s\"\n\n" "${POSTGREY_TEXT}" >> /etc/default/postgrey
  fi

  if [[ -f /tmp/docker-mailserver/whitelist_clients.local ]]
  then
    cp -f /tmp/docker-mailserver/whitelist_clients.local /etc/postgrey/whitelist_clients.local
  fi

  if [[ -f /tmp/docker-mailserver/whitelist_recipients ]]
  then
    cp -f /tmp/docker-mailserver/whitelist_recipients /etc/postgrey/whitelist_recipients
  fi
}

function _setup_postfix_postscreen
{
  _notify 'inf' "Configuring postscreen"
  sed -i -e "s/postscreen_dnsbl_action = enforce/postscreen_dnsbl_action = ${POSTSCREEN_ACTION}/" \
    -e "s/postscreen_greet_action = enforce/postscreen_greet_action = ${POSTSCREEN_ACTION}/" \
    -e "s/postscreen_bare_newline_action = enforce/postscreen_bare_newline_action = ${POSTSCREEN_ACTION}/" /etc/postfix/main.cf
}

function _setup_postfix_sizelimits
{
  _notify 'inf' "Configuring postfix message size limit"
  postconf -e "message_size_limit = ${POSTFIX_MESSAGE_SIZE_LIMIT}"

  _notify 'inf' "Configuring postfix mailbox size limit"
  postconf -e "mailbox_size_limit = ${POSTFIX_MAILBOX_SIZE_LIMIT}"

  _notify 'inf' "Configuring postfix virtual mailbox size limit"
  postconf -e "virtual_mailbox_limit = ${POSTFIX_MAILBOX_SIZE_LIMIT}"
}

function _setup_postfix_smtputf8
{
  _notify 'inf' "Configuring postfix smtputf8 support (disable)"
  postconf -e "smtputf8_enable = no"
}

function _setup_spoof_protection
{
  _notify 'inf' "Configuring Spoof Protection"
  sed -i 's|smtpd_sender_restrictions =|smtpd_sender_restrictions = reject_authenticated_sender_login_mismatch,|' /etc/postfix/main.cf

  # shellcheck disable=SC2015
  [[ ${ENABLE_LDAP} -eq 1 ]] && postconf -e "smtpd_sender_login_maps=ldap:/etc/postfix/ldap-users.cf ldap:/etc/postfix/ldap-aliases.cf ldap:/etc/postfix/ldap-groups.cf" || postconf -e "smtpd_sender_login_maps=texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/regexp, pcre:/etc/postfix/maps/sender_login_maps.pcre"
}

function _setup_postfix_access_control
{
  _notify 'inf' "Configuring user access"

  if [[ -f /tmp/docker-mailserver/postfix-send-access.cf ]]
  then
    sed -i 's|smtpd_sender_restrictions =|smtpd_sender_restrictions = check_sender_access texthash:/tmp/docker-mailserver/postfix-send-access.cf,|' /etc/postfix/main.cf
  fi

  if [[ -f /tmp/docker-mailserver/postfix-receive-access.cf ]]
  then
    sed -i 's|smtpd_recipient_restrictions =|smtpd_recipient_restrictions = check_recipient_access texthash:/tmp/docker-mailserver/postfix-receive-access.cf,|' /etc/postfix/main.cf
  fi
}

function _setup_postfix_sasl
{
  if [[ ${ENABLE_SASLAUTHD} -eq 1 ]]
  then
    [[ ! -f /etc/postfix/sasl/smtpd.conf ]] && cat > /etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
mech_list: plain login
EOF
  fi

  # cyrus sasl or dovecot sasl
  if [[ ${ENABLE_SASLAUTHD} -eq 1 ]] || [[ ${SMTP_ONLY} -eq 0 ]]
  then
    sed -i -e 's|^smtpd_sasl_auth_enable[[:space:]]\+.*|smtpd_sasl_auth_enable = yes|g' /etc/postfix/main.cf
  else
    sed -i -e 's|^smtpd_sasl_auth_enable[[:space:]]\+.*|smtpd_sasl_auth_enable = no|g' /etc/postfix/main.cf
  fi

  return 0
}

function _setup_saslauthd
{
  _notify 'task' "Setting up Saslauthd"
  _notify 'inf' "Configuring Cyrus SASL"

  # checking env vars and setting defaults
  [[ -z ${SASLAUTHD_MECHANISMS:-} ]] && SASLAUTHD_MECHANISMS=pam
  [[ ${SASLAUTHD_MECHANISMS:-} == ldap ]] && [[ -z ${SASLAUTHD_LDAP_SEARCH_BASE} ]] && SASLAUTHD_MECHANISMS=pam
  [[ -z ${SASLAUTHD_LDAP_SERVER} ]] && SASLAUTHD_LDAP_SERVER=localhost
  [[ -z ${SASLAUTHD_LDAP_FILTER} ]] && SASLAUTHD_LDAP_FILTER='(&(uniqueIdentifier=%u)(mailEnabled=TRUE))'

  if [[ -z ${SASLAUTHD_LDAP_SSL} ]] || [[ ${SASLAUTHD_LDAP_SSL} -eq 0 ]]
  then
    SASLAUTHD_LDAP_PROTO='ldap://' || SASLAUTHD_LDAP_PROTO='ldaps://'
  fi

  [[ -z ${SASLAUTHD_LDAP_START_TLS} ]] && SASLAUTHD_LDAP_START_TLS=no
  [[ -z ${SASLAUTHD_LDAP_TLS_CHECK_PEER} ]] && SASLAUTHD_LDAP_TLS_CHECK_PEER=no
  [[ -z ${SASLAUTHD_LDAP_AUTH_METHOD} ]] && SASLAUTHD_LDAP_AUTH_METHOD=bind

  if [[ -z ${SASLAUTHD_LDAP_TLS_CACERT_FILE} ]]
  then
    SASLAUTHD_LDAP_TLS_CACERT_FILE=""
  else
    SASLAUTHD_LDAP_TLS_CACERT_FILE="ldap_tls_cacert_file: ${SASLAUTHD_LDAP_TLS_CACERT_FILE}"
  fi

  if [[ -z ${SASLAUTHD_LDAP_TLS_CACERT_DIR} ]]
  then
    SASLAUTHD_LDAP_TLS_CACERT_DIR=""
  else
    SASLAUTHD_LDAP_TLS_CACERT_DIR="ldap_tls_cacert_dir: ${SASLAUTHD_LDAP_TLS_CACERT_DIR}"
  fi

  if [[ -z ${SASLAUTHD_LDAP_PASSWORD_ATTR} ]]
  then
    SASLAUTHD_LDAP_PASSWORD_ATTR=""
  else
    SASLAUTHD_LDAP_PASSWORD_ATTR="ldap_password_attr: ${SASLAUTHD_LDAP_PASSWORD_ATTR}"
  fi

  if [[ -z ${SASLAUTHD_LDAP_MECH} ]]
  then
    SASLAUTHD_LDAP_MECH=""
  else
    SASLAUTHD_LDAP_MECH="ldap_mech: ${SASLAUTHD_LDAP_MECH}"
  fi

  if [[ ! -f /etc/saslauthd.conf ]]
  then
    _notify 'inf' "Creating /etc/saslauthd.conf"
    cat > /etc/saslauthd.conf << EOF
ldap_servers: ${SASLAUTHD_LDAP_PROTO}${SASLAUTHD_LDAP_SERVER}

ldap_auth_method: ${SASLAUTHD_LDAP_AUTH_METHOD}
ldap_bind_dn: ${SASLAUTHD_LDAP_BIND_DN}
ldap_bind_pw: ${SASLAUTHD_LDAP_PASSWORD}

ldap_search_base: ${SASLAUTHD_LDAP_SEARCH_BASE}
ldap_filter: ${SASLAUTHD_LDAP_FILTER}

ldap_start_tls: ${SASLAUTHD_LDAP_START_TLS}
ldap_tls_check_peer: ${SASLAUTHD_LDAP_TLS_CHECK_PEER}

${SASLAUTHD_LDAP_TLS_CACERT_FILE}
${SASLAUTHD_LDAP_TLS_CACERT_DIR}
${SASLAUTHD_LDAP_PASSWORD_ATTR}
${SASLAUTHD_LDAP_MECH}

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

function _setup_postfix_aliases
{
  _notify 'task' 'Setting up Postfix Aliases'

  : >/etc/postfix/virtual
  : >/etc/postfix/regexp

  if [[ -f /tmp/docker-mailserver/postfix-virtual.cf ]]
  then
    # fixing old virtual user file
    if grep -q ",$" /tmp/docker-mailserver/postfix-virtual.cf
    then
      sed -i -e "s/, /,/g" -e "s/,$//g" /tmp/docker-mailserver/postfix-virtual.cf
    fi

    cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual

    # the `to` is important, don't delete it
    # shellcheck disable=SC2034
    while read -r FROM TO
    do
      UNAME=$(echo "${FROM}" | cut -d @ -f1)
      DOMAIN=$(echo "${FROM}" | cut -d @ -f2)

      # if they are equal it means the line looks like: "user1     other@domain.tld"
      [[ ${UNAME} != "${DOMAIN}" ]] && echo "${DOMAIN}" >>/tmp/vhost.tmp
    done < <(grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-virtual.cf || true)
  else
    _notify 'inf' "Warning 'config/postfix-virtual.cf' is not provided. No mail alias/forward created."
  fi

  if [[ -f /tmp/docker-mailserver/postfix-regexp.cf ]]
  then
    _notify 'inf' "Adding regexp alias file postfix-regexp.cf"

    cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
    sed -i -e '/^virtual_alias_maps/{
s/ pcre:.*//
s/$/ pcre:\/etc\/postfix\/regexp/
}' /etc/postfix/main.cf
  fi

  _notify 'inf' "Configuring root alias"

  echo "root: ${POSTMASTER_ADDRESS}" > /etc/aliases

  if [[ -f /tmp/docker-mailserver/postfix-aliases.cf ]]
  then
    cat /tmp/docker-mailserver/postfix-aliases.cf >> /etc/aliases
  else
    _notify 'inf' "'config/postfix-aliases.cf' is not provided and will be auto created."
    : >/tmp/docker-mailserver/postfix-aliases.cf
  fi

  postalias /etc/aliases
}

function _setup_SRS
{
  _notify 'task' 'Setting up SRS'

  postconf -e "sender_canonical_maps = tcp:localhost:10001"
  postconf -e "sender_canonical_classes = ${SRS_SENDER_CLASSES}"
  postconf -e "recipient_canonical_maps = tcp:localhost:10002"
  postconf -e "recipient_canonical_classes = envelope_recipient,header_recipient"
}

function _setup_dkim
{
  _notify 'task' 'Setting up DKIM'

  mkdir -p /etc/opendkim && touch /etc/opendkim/SigningTable

  # Check if keys are already available
  if [[ -e "/tmp/docker-mailserver/opendkim/KeyTable" ]]
  then
    cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/

    _notify 'inf' "DKIM keys added for: $(ls -C /etc/opendkim/keys/)"
    _notify 'inf' "Changing permissions on /etc/opendkim"

    chown -R opendkim:opendkim /etc/opendkim/
    chmod -R 0700 /etc/opendkim/keys/ # make sure permissions are right
  else
    _notify 'warn' "No DKIM key provided. Check the documentation to find how to get your keys."

    local KEYTABLE_FILE="/etc/opendkim/KeyTable"
    [[ ! -f ${KEYTABLE_FILE} ]] && touch "${KEYTABLE_FILE}"
  fi

  # setup nameservers paramater from /etc/resolv.conf if not defined
  if ! grep '^Nameservers' /etc/opendkim.conf
  then
    echo "Nameservers $(grep '^nameserver' /etc/resolv.conf | awk -F " " '{print $2}' | paste -sd ',' -)" >> /etc/opendkim.conf

    _notify 'inf' "Nameservers added to /etc/opendkim.conf"
  fi
}

function _setup_ssl
{
  _notify 'task' 'Setting up SSL'

  # TLS strength/level configuration
  case "${TLS_LEVEL}" in
    "modern" )
      # Postfix configuration
      sed -i -r 's/^smtpd_tls_mandatory_protocols =.*$/smtpd_tls_mandatory_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1/' /etc/postfix/main.cf
      sed -i -r 's/^smtpd_tls_protocols =.*$/smtpd_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1/' /etc/postfix/main.cf
      sed -i -r 's/^smtp_tls_protocols =.*$/smtp_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1/' /etc/postfix/main.cf
      sed -i -r 's/^tls_high_cipherlist =.*$/tls_high_cipherlist = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256/' /etc/postfix/main.cf

      # Dovecot configuration (secure by default though)
      sed -i -r 's/^ssl_min_protocol =.*$/ssl_min_protocol = TLSv1.2/' /etc/dovecot/conf.d/10-ssl.conf
      sed -i -r 's/^ssl_cipher_list =.*$/ssl_cipher_list = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256/' /etc/dovecot/conf.d/10-ssl.conf

      _notify 'inf' "TLS configured with 'modern' ciphers"
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

      _notify 'inf' "TLS configured with 'intermediate' ciphers"
      ;;

    * )
      _notify 'err' 'TLS_LEVEL not found [ in _setup_ssl ]'
      ;;

  esac

  # SSL certificate Configuration
  case "${SSL_TYPE}" in
    "letsencrypt" )
      _notify 'inf' "Configuring SSL using 'letsencrypt'"
      # letsencrypt folders and files mounted in /etc/letsencrypt
      local LETSENCRYPT_DOMAIN=""
      local LETSENCRYPT_KEY=""

      if [[ -f /etc/letsencrypt/acme.json ]]
      then
        if ! _extract_certs_from_acme "${SSL_DOMAIN}"
        then
          if ! _extract_certs_from_acme "${HOSTNAME}"
          then
            _extract_certs_from_acme "${DOMAINNAME}"
          fi
        fi
      fi

      # first determine the letsencrypt domain by checking both the full hostname or just the domainname if a SAN is used in the cert
      if [[ -e /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem ]]
      then
        LETSENCRYPT_DOMAIN=${HOSTNAME}
      elif [[ -e /etc/letsencrypt/live/${DOMAINNAME}/fullchain.pem ]]
      then
        LETSENCRYPT_DOMAIN=${DOMAINNAME}
      else
        _notify 'err' "Cannot access '/etc/letsencrypt/live/${HOSTNAME}/fullchain.pem' or '/etc/letsencrypt/live/${DOMAINNAME}/fullchain.pem'"
        return 1
      fi

      # then determine the keyfile to use
      if [[ -n ${LETSENCRYPT_DOMAIN} ]]
      then
        if [[ -e /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/privkey.pem ]]
        then
          LETSENCRYPT_KEY="privkey"
        elif [[ -e /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/key.pem ]]
        then
          LETSENCRYPT_KEY="key"
        else
          _notify 'err' "Cannot access '/etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/privkey.pem' nor 'key.pem'"
          return 1
        fi
      fi

      # finally, make the changes to the postfix and dovecot configurations
      if [[ -n ${LETSENCRYPT_KEY} ]]
      then
        _notify 'inf' "Adding ${LETSENCRYPT_DOMAIN} SSL certificate to the postfix and dovecot configuration"

        # Postfix configuration
        sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/letsencrypt/live/'"${LETSENCRYPT_DOMAIN}"'/fullchain.pem~g' /etc/postfix/main.cf
        sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/letsencrypt/live/'"${LETSENCRYPT_DOMAIN}"'/'"${LETSENCRYPT_KEY}"'\.pem~g' /etc/postfix/main.cf

        # Dovecot configuration
        sed -i -e 's~ssl_cert = </etc/dovecot/ssl/dovecot\.pem~ssl_cert = </etc/letsencrypt/live/'"${LETSENCRYPT_DOMAIN}"'/fullchain\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
        sed -i -e 's~ssl_key = </etc/dovecot/ssl/dovecot\.key~ssl_key = </etc/letsencrypt/live/'"${LETSENCRYPT_DOMAIN}"'/'"${LETSENCRYPT_KEY}"'\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

        _notify 'inf' "SSL configured with 'letsencrypt' certificates"
      fi
      return 0
      ;;
    "custom" )
      # Adding CA signed SSL certificate if provided in 'postfix/ssl' folder
      if [[ -e /tmp/docker-mailserver/ssl/${HOSTNAME}-full.pem ]]
      then
        _notify 'inf' "Adding ${HOSTNAME} SSL certificate"

        mkdir -p /etc/postfix/ssl
        cp "/tmp/docker-mailserver/ssl/${HOSTNAME}-full.pem" /etc/postfix/ssl

        # Postfix configuration
        sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/'"${HOSTNAME}"'-full.pem~g' /etc/postfix/main.cf
        sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/'"${HOSTNAME}"'-full.pem~g' /etc/postfix/main.cf

        # Dovecot configuration
        sed -i -e 's~ssl_cert = </etc/dovecot/ssl/dovecot\.pem~ssl_cert = </etc/postfix/ssl/'"${HOSTNAME}"'-full\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
        sed -i -e 's~ssl_key = </etc/dovecot/ssl/dovecot\.key~ssl_key = </etc/postfix/ssl/'"${HOSTNAME}"'-full\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

        _notify 'inf' "SSL configured with 'CA signed/custom' certificates"
      fi
      ;;
    "manual" )
      # Lets you manually specify the location of the SSL Certs to use. This gives you some more control over this whole  processes (like using kube-lego to generate certs)
      if [[ -n ${SSL_CERT_PATH} ]] && [[ -n ${SSL_KEY_PATH} ]]
      then
        _notify 'inf' "Configuring certificates using cert ${SSL_CERT_PATH} and key ${SSL_KEY_PATH}"

        mkdir -p /etc/postfix/ssl
        cp "${SSL_CERT_PATH}" /etc/postfix/ssl/cert
        cp "${SSL_KEY_PATH}" /etc/postfix/ssl/key
        chmod 600 /etc/postfix/ssl/cert
        chmod 600 /etc/postfix/ssl/key

        # Postfix configuration
        sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/cert~g' /etc/postfix/main.cf
        sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/key~g' /etc/postfix/main.cf

        # Dovecot configuration
        sed -i -e 's~ssl_cert = </etc/dovecot/ssl/dovecot\.pem~ssl_cert = </etc/postfix/ssl/cert~g' /etc/dovecot/conf.d/10-ssl.conf
        sed -i -e 's~ssl_key = </etc/dovecot/ssl/dovecot\.key~ssl_key = </etc/postfix/ssl/key~g' /etc/dovecot/conf.d/10-ssl.conf

        _notify 'inf' "SSL configured with 'Manual' certificates"
      fi
      ;;
    "self-signed" )
      # Adding self-signed SSL certificate if provided in 'postfix/ssl' folder
      if [[ -e /tmp/docker-mailserver/ssl/${HOSTNAME}-cert.pem ]] \
      && [[ -e /tmp/docker-mailserver/ssl/${HOSTNAME}-key.pem ]] \
      && [[ -e /tmp/docker-mailserver/ssl/${HOSTNAME}-combined.pem ]] \
      && [[ -e /tmp/docker-mailserver/ssl/demoCA/cacert.pem ]]
      then
        _notify 'inf' "Adding ${HOSTNAME} SSL certificate"

        mkdir -p /etc/postfix/ssl
        cp "/tmp/docker-mailserver/ssl/${HOSTNAME}-cert.pem" /etc/postfix/ssl
        cp "/tmp/docker-mailserver/ssl/${HOSTNAME}-key.pem" /etc/postfix/ssl

        # Force permission on key file
        chmod 600 "/etc/postfix/ssl/${HOSTNAME}-key.pem"
        cp "/tmp/docker-mailserver/ssl/${HOSTNAME}-combined.pem" /etc/postfix/ssl
        cp /tmp/docker-mailserver/ssl/demoCA/cacert.pem /etc/postfix/ssl

        # Postfix configuration
        sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/'"${HOSTNAME}"'-cert.pem~g' /etc/postfix/main.cf
        sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/'"${HOSTNAME}"'-key.pem~g' /etc/postfix/main.cf
        sed -i -r 's~#smtpd_tls_CAfile=~smtpd_tls_CAfile=/etc/postfix/ssl/cacert.pem~g' /etc/postfix/main.cf
        sed -i -r 's~#smtp_tls_CAfile=~smtp_tls_CAfile=/etc/postfix/ssl/cacert.pem~g' /etc/postfix/main.cf

        ln -s /etc/postfix/ssl/cacert.pem "/etc/ssl/certs/cacert-${HOSTNAME}.pem"

        # Dovecot configuration
        sed -i -e 's~ssl_cert = </etc/dovecot/ssl/dovecot\.pem~ssl_cert = </etc/postfix/ssl/'"${HOSTNAME}"'-combined\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
        sed -i -e 's~ssl_key = </etc/dovecot/ssl/dovecot\.key~ssl_key = </etc/postfix/ssl/'"${HOSTNAME}"'-key\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

        _notify 'inf' "SSL configured with 'self-signed' certificates"
      fi
      ;;
    '' )
      # no SSL certificate, plain text access

      # Dovecot configuration
      sed -i -e 's~#disable_plaintext_auth = yes~disable_plaintext_auth = no~g' /etc/dovecot/conf.d/10-auth.conf
      sed -i -e 's~ssl = required~ssl = yes~g' /etc/dovecot/conf.d/10-ssl.conf

      _notify 'inf' "SSL configured with plain text access"
      ;;
    * )
      # Unknown option, default behavior, no action is required
      _notify 'warn' "SSL configured by default"
      ;;
  esac
}

function _setup_postfix_vhost
{
  _notify 'task' "Setting up Postfix vhost"

  if [[ -f /tmp/vhost.tmp ]]
  then
    sort < /tmp/vhost.tmp | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
  elif [[ ! -f /etc/postfix/vhost ]]
  then
    touch /etc/postfix/vhost
  fi
}

function _setup_inet_protocols
{
  _notify 'task' 'Setting up POSTFIX_INET_PROTOCOLS option'
  postconf -e "inet_protocols = ${POSTFIX_INET_PROTOCOLS}"
}

function _setup_docker_permit
{
  _notify 'task' 'Setting up PERMIT_DOCKER Option'

  local CONTAINER_IP CONTAINER_NETWORK

  unset CONTAINER_NETWORKS
  declare -a CONTAINER_NETWORKS

  CONTAINER_IP=$(ip addr show "${NETWORK_INTERFACE}" | grep 'inet ' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1)
  CONTAINER_NETWORK="$(echo "${CONTAINER_IP}" | cut -d '.' -f1-2).0.0"

  while read -r IP
  do
    CONTAINER_NETWORKS+=("${IP}")
  done < <(ip -o -4 addr show type veth | grep -E -o '[0-9\.]+/[0-9]+')

  case ${PERMIT_DOCKER} in
    "host" )
      _notify 'inf' "Adding ${CONTAINER_NETWORK}/16 to my networks"
      postconf -e "$(postconf | grep '^mynetworks =') ${CONTAINER_NETWORK}/16"
      echo "${CONTAINER_NETWORK}/16" >> /etc/opendmarc/ignore.hosts
      echo "${CONTAINER_NETWORK}/16" >> /etc/opendkim/TrustedHosts
      ;;

    "network" )
      _notify 'inf' "Adding docker network in my networks"
      postconf -e "$(postconf | grep '^mynetworks =') 172.16.0.0/12"
      echo 172.16.0.0/12 >> /etc/opendmarc/ignore.hosts
      echo 172.16.0.0/12 >> /etc/opendkim/TrustedHosts
      ;;
    "connected-networks" )
      for NETWORK in "${CONTAINER_NETWORKS[@]}"
      do
        NETWORK=$(_sanitize_ipv4_to_subnet_cidr "${NETWORK}")
        _notify 'inf' "Adding docker network ${NETWORK} in my networks"
        postconf -e "$(postconf | grep '^mynetworks =') ${NETWORK}"
        echo "${NETWORK}" >> /etc/opendmarc/ignore.hosts
        echo "${NETWORK}" >> /etc/opendkim/TrustedHosts
      done
      ;;
    * )
      _notify 'inf' "Adding container ip in my networks"
      postconf -e "$(postconf | grep '^mynetworks =') ${CONTAINER_IP}/32"
      echo "${CONTAINER_IP}/32" >> /etc/opendmarc/ignore.hosts
      echo "${CONTAINER_IP}/32" >> /etc/opendkim/TrustedHosts
      ;;
  esac
}

function _setup_postfix_virtual_transport
{
  _notify 'task' 'Setting up Postfix virtual transport'

  [[ -z ${POSTFIX_DAGENT} ]] && echo "${POSTFIX_DAGENT} not set." && \
    kill -15 "$(< /var/run/supervisord.pid)" && return 1

  postconf -e "virtual_transport = ${POSTFIX_DAGENT}"
}

function _setup_postfix_override_configuration
{
  _notify 'task' 'Setting up Postfix Override configuration'

  if [[ -f /tmp/docker-mailserver/postfix-main.cf ]]
  then
    while read -r LINE
    do
      # all valid postfix options start with a lower case letter
      # http://www.postfix.org/postconf.5.html
      if [[ ${LINE} =~ ^[a-z] ]]
      then
        postconf -e "${LINE}"
      fi
    done < /tmp/docker-mailserver/postfix-main.cf
    _notify 'inf' "Loaded 'config/postfix-main.cf'"
  else
    _notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailserver/postfix-main.cf' not provided."
  fi

  if [[ -f /tmp/docker-mailserver/postfix-master.cf ]]
  then
    while read -r LINE
    do
      if [[ ${LINE} =~ ^[0-9a-z] ]]
      then
        postconf -P "${LINE}"
      fi
    done < /tmp/docker-mailserver/postfix-master.cf
    _notify 'inf' "Loaded 'config/postfix-master.cf'"
  else
    _notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailserver/postfix-master.cf' not provided."
  fi

  _notify 'inf' "set the compatibility level to 2"
  postconf compatibility_level=2
}

function _setup_postfix_sasl_password
{
  _notify 'task' 'Setting up Postfix SASL Password'

  # support general SASL password
  rm -f /etc/postfix/sasl_passwd
  if [[ -n ${SASL_PASSWD} ]]
  then
    echo "${SASL_PASSWD}" >> /etc/postfix/sasl_passwd
  fi

  # install SASL passwords
  if [[ -f /etc/postfix/sasl_passwd ]]
  then
    chown root:root /etc/postfix/sasl_passwd
    chmod 0600 /etc/postfix/sasl_passwd
    _notify 'inf' "Loaded SASL_PASSWD"
  else
    _notify 'inf' "Warning: 'SASL_PASSWD' is not provided. /etc/postfix/sasl_passwd not created."
  fi
}

function _setup_postfix_default_relay_host
{
  _notify 'task' 'Applying default relay host to Postfix'

  _notify 'inf' "Applying default relay host ${DEFAULT_RELAY_HOST} to /etc/postfix/main.cf"
  postconf -e "relayhost = ${DEFAULT_RELAY_HOST}"
}

function _setup_postfix_relay_hosts
{
  _notify 'task' 'Setting up Postfix Relay Hosts'

  [[ -z ${RELAY_PORT} ]] && RELAY_PORT=25

  _notify 'inf' "Setting up outgoing email relaying via ${RELAY_HOST}:${RELAY_PORT}"

  # setup /etc/postfix/sasl_passwd
  # --
  # @domain1.com        postmaster@domain1.com:your-password-1
  # @domain2.com        postmaster@domain2.com:your-password-2
  # @domain3.com        postmaster@domain3.com:your-password-3
  #
  # [smtp.mailgun.org]:587  postmaster@domain2.com:your-password-2

  if [[ -f /tmp/docker-mailserver/postfix-sasl-password.cf ]]
  then
    _notify 'inf' "Adding relay authentication from postfix-sasl-password.cf"

    while read -r LINE
    do
      if ! echo "${LINE}" | grep -q -e "^\s*#"
      then
        echo "${LINE}" >> /etc/postfix/sasl_passwd
      fi
    done < /tmp/docker-mailserver/postfix-sasl-password.cf
  fi

  # add default relay
  if [[ -n ${RELAY_USER} ]] && [[ -n ${RELAY_PASSWORD} ]]
  then
    echo "[${RELAY_HOST}]:${RELAY_PORT}		${RELAY_USER}:${RELAY_PASSWORD}" >> /etc/postfix/sasl_passwd
  else
    if [[ ! -f /tmp/docker-mailserver/postfix-sasl-password.cf ]]
    then
      _notify 'warn' "No relay auth file found and no default set"
    fi
  fi

  if [[ -f /etc/postfix/sasl_passwd ]]
  then
    chown root:root /etc/postfix/sasl_passwd
    chmod 0600 /etc/postfix/sasl_passwd
  fi
  # end /etc/postfix/sasl_passwd

  _populate_relayhost_map

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

function _setup_postfix_dhparam
{
  _notify 'task' 'Setting up Postfix dhparam'

  if [[ ${ONE_DIR} -eq 1 ]]
  then
    DHPARAMS_FILE=/var/mail-state/lib-shared/dhparams.pem

    if [[ ! -f ${DHPARAMS_FILE} ]]
    then
      _notify 'inf' "Use ffdhe4096 for dhparams (postfix)"
      cp -f /etc/postfix/shared/ffdhe4096.pem /etc/postfix/dhparams.pem
    else
      _notify 'inf' "Use postfix dhparams that was generated previously"
      _notify 'warn' "Using self-generated dhparams is considered as insecure."
      _notify 'warn' "Unless you known what you are doing, please remove /var/mail-state/lib-shared/dhparams.pem."

      # Copy from the state directory to the working location
      cp -f "${DHPARAMS_FILE}" /etc/postfix/dhparams.pem
    fi
  else
    if [[ ! -f /etc/postfix/dhparams.pem ]]
    then
      if [[ -f /etc/dovecot/dh.pem ]]
      then
        _notify 'inf' "Copy dovecot dhparams to postfix"
        cp /etc/dovecot/dh.pem /etc/postfix/dhparams.pem
      elif [[ -f /tmp/docker-mailserver/dhparams.pem ]]
      then
        _notify 'inf' "Copy pre-generated dhparams to postfix"
        _notify 'warn' "Using self-generated dhparams is considered as insecure."
        _notify 'warn' "Unless you known what you are doing, please remove /var/mail-state/lib-shared/dhparams.pem."
        cp /tmp/docker-mailserver/dhparams.pem /etc/postfix/dhparams.pem
      else
        _notify 'inf' "Use ffdhe4096 for dhparams (postfix)"
        cp /etc/postfix/shared/ffdhe4096.pem /etc/postfix/dhparams.pem
      fi
    else
      _notify 'inf' "Use existing postfix dhparams"
      _notify 'warn' "Using self-generated dhparams is considered insecure."
      _notify 'warn' "Unless you known what you are doing, please remove /etc/postfix/dhparams.pem."
    fi
  fi
}

function _setup_dovecot_dhparam
{
  _notify 'task' 'Setting up Dovecot dhparam'

  if [[ ${ONE_DIR} -eq 1 ]]
  then
    DHPARAMS_FILE=/var/mail-state/lib-shared/dhparams.pem

    if [[ ! -f ${DHPARAMS_FILE} ]]
    then
      _notify 'inf' "Use ffdhe4096 for dhparams (dovecot)"
      cp -f /etc/postfix/shared/ffdhe4096.pem /etc/dovecot/dh.pem
    else
      _notify 'inf' "Use dovecot dhparams that was generated previously"
      _notify 'warn' "Using self-generated dhparams is considered as insecure."
      _notify 'warn' "Unless you known what you are doing, please remove /var/mail-state/lib-shared/dhparams.pem."

      # Copy from the state directory to the working location
      cp -f "${DHPARAMS_FILE}" /etc/dovecot/dh.pem
    fi
  else
    if [[ ! -f /etc/dovecot/dh.pem ]]
    then
      if [[ -f /etc/postfix/dhparams.pem ]]
      then
        _notify 'inf' "Copy postfix dhparams to dovecot"
        cp /etc/postfix/dhparams.pem /etc/dovecot/dh.pem
      elif [[ -f /tmp/docker-mailserver/dhparams.pem ]]
      then
        _notify 'inf' "Copy pre-generated dhparams to dovecot"
        _notify 'warn' "Using self-generated dhparams is considered as insecure."
        _notify 'warn' "Unless you known what you are doing, please remove /tmp/docker-mailserver/dhparams.pem."

        cp /tmp/docker-mailserver/dhparams.pem /etc/dovecot/dh.pem
      else
        _notify 'inf' "Use ffdhe4096 for dhparams (dovecot)"
        cp /etc/postfix/shared/ffdhe4096.pem /etc/dovecot/dh.pem
      fi
    else
      _notify 'inf' "Use existing dovecot dhparams"
      _notify 'warn' "Using self-generated dhparams is considered as insecure."
      _notify 'warn' "Unless you known what you are doing, please remove /etc/dovecot/dh.pem."
    fi
  fi
}

function _setup_security_stack
{
  _notify 'task' "Setting up Security Stack"

  # recreate auto-generated file
  local DMS_AMAVIS_FILE=/etc/amavis/conf.d/61-dms_auto_generated

  echo "# WARNING: this file is auto-generated." >"${DMS_AMAVIS_FILE}"
  echo "use strict;" >>"${DMS_AMAVIS_FILE}"

  # Spamassassin
  if [[ ${ENABLE_SPAMASSASSIN} -eq 0 ]]
  then
    _notify 'warn' "Spamassassin is disabled. You can enable it with 'ENABLE_SPAMASSASSIN=1'"
    echo "@bypass_spam_checks_maps = (1);" >>"${DMS_AMAVIS_FILE}"
  elif [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]]
  then
    _notify 'inf' "Enabling and configuring spamassassin"

    # shellcheck disable=SC2016
    SA_TAG=${SA_TAG:="2.0"} && sed -i -r 's/^\$sa_tag_level_deflt (.*);/\$sa_tag_level_deflt = '"${SA_TAG}"';/g' /etc/amavis/conf.d/20-debian_defaults

    # shellcheck disable=SC2016
    SA_TAG2=${SA_TAG2:="6.31"} && sed -i -r 's/^\$sa_tag2_level_deflt (.*);/\$sa_tag2_level_deflt = '"${SA_TAG2}"';/g' /etc/amavis/conf.d/20-debian_defaults

    # shellcheck disable=SC2016
    SA_KILL=${SA_KILL:="6.31"} && sed -i -r 's/^\$sa_kill_level_deflt (.*);/\$sa_kill_level_deflt = '"${SA_KILL}"';/g' /etc/amavis/conf.d/20-debian_defaults

    SA_SPAM_SUBJECT=${SA_SPAM_SUBJECT:="***SPAM*** "}

    if [[ ${SA_SPAM_SUBJECT} == "undef" ]]
    then
      # shellcheck disable=SC2016
      sed -i -r 's/^\$sa_spam_subject_tag (.*);/\$sa_spam_subject_tag = undef;/g' /etc/amavis/conf.d/20-debian_defaults
    else
      # shellcheck disable=SC2016
      sed -i -r 's/^\$sa_spam_subject_tag (.*);/\$sa_spam_subject_tag = '"'${SA_SPAM_SUBJECT}'"';/g' /etc/amavis/conf.d/20-debian_defaults
    fi

    # activate short circuits when SA BAYES is certain it has spam or ham.
    if [[ ${SA_SHORTCIRCUIT_BAYES_SPAM} -eq 1 ]]
    then
      # automatically activate the Shortcircuit Plugin
      sed -i -r 's/^# loadplugin Mail::SpamAssassin::Plugin::Shortcircuit/loadplugin Mail::SpamAssassin::Plugin::Shortcircuit/g' /etc/spamassassin/v320.pre
      sed -i -r 's/^# shortcircuit BAYES_99/shortcircuit BAYES_99/g' /etc/spamassassin/local.cf
    fi

    if [[ ${SA_SHORTCIRCUIT_BAYES_HAM} -eq 1 ]]
    then
      # automatically activate the Shortcircuit Plugin
      sed -i -r 's/^# loadplugin Mail::SpamAssassin::Plugin::Shortcircuit/loadplugin Mail::SpamAssassin::Plugin::Shortcircuit/g' /etc/spamassassin/v320.pre
      sed -i -r 's/^# shortcircuit BAYES_00/shortcircuit BAYES_00/g' /etc/spamassassin/local.cf
    fi

    if [[ -e /tmp/docker-mailserver/spamassassin-rules.cf ]]
    then
      cp /tmp/docker-mailserver/spamassassin-rules.cf /etc/spamassassin/
    fi


    if [[ ${SPAMASSASSIN_SPAM_TO_INBOX} -eq 1 ]]
    then
      _notify 'inf' "Configure Spamassassin/Amavis to put SPAM inbox"

      sed -i "s/\$final_spam_destiny.*=.*$/\$final_spam_destiny = D_PASS;/g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s/\$final_bad_header_destiny.*=.*$/\$final_bad_header_destiny = D_PASS;/g" /etc/amavis/conf.d/49-docker-mailserver
    else
      sed -i "s/\$final_spam_destiny.*=.*$/\$final_spam_destiny = D_BOUNCE;/g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s/\$final_bad_header_destiny.*=.*$/\$final_bad_header_destiny = D_BOUNCE;/g" /etc/amavis/conf.d/49-docker-mailserver

      if ! ${SPAMASSASSIN_SPAM_TO_INBOX_IS_SET}
      then
        _notify 'warn' "Spam messages WILL NOT BE DELIVERED, you will NOT be notified of ANY message bounced. Please define SPAMASSASSIN_SPAM_TO_INBOX explicitly."
      fi
    fi
  fi

  # Clamav
  if [[ ${ENABLE_CLAMAV} -eq 0 ]]
  then
    _notify 'warn' "Clamav is disabled. You can enable it with 'ENABLE_CLAMAV=1'"
    echo "@bypass_virus_checks_maps = (1);" >>"${DMS_AMAVIS_FILE}"
  elif [[ ${ENABLE_CLAMAV} -eq 1 ]]
  then
    _notify 'inf' "Enabling clamav"
  fi

  echo "1;  # ensure a defined return" >>"${DMS_AMAVIS_FILE}"
  chmod 444 "${DMS_AMAVIS_FILE}"

  # Fail2ban
  if [[ ${ENABLE_FAIL2BAN} -eq 1 ]]
  then
    _notify 'inf' "Fail2ban enabled"

    if [[ -e /tmp/docker-mailserver/fail2ban-fail2ban.cf ]]
    then
      cp /tmp/docker-mailserver/fail2ban-fail2ban.cf /etc/fail2ban/fail2ban.local
    fi

    if [[ -e /tmp/docker-mailserver/fail2ban-jail.cf ]]
    then
      cp /tmp/docker-mailserver/fail2ban-jail.cf /etc/fail2ban/jail.local
    fi
  else
    # disable logrotate config for fail2ban if not enabled
    rm -f /etc/logrotate.d/fail2ban
  fi

  # fix cron.daily for spamassassin
  sed -i -e 's~invoke-rc.d spamassassin reload~/etc/init\.d/spamassassin reload~g' /etc/cron.daily/spamassassin

  # copy user provided configuration files if provided
  if [[ -f /tmp/docker-mailserver/amavis.cf ]]
  then
    cp /tmp/docker-mailserver/amavis.cf /etc/amavis/conf.d/50-user
  fi
}

function _setup_logrotate
{
  _notify 'inf' "Setting up logrotate"

  LOGROTATE='/var/log/mail/mail.log\n{\n  compress\n  copytruncate\n  delaycompress\n'

  case "${LOGROTATE_INTERVAL}" in
    "daily" )
      _notify 'inf' "Setting postfix logrotate interval to daily"
      LOGROTATE="${LOGROTATE}  rotate 4\n  daily\n"
      ;;
    "weekly" )
      _notify 'inf' "Setting postfix logrotate interval to weekly"
      LOGROTATE="${LOGROTATE}  rotate 4\n  weekly\n"
      ;;
    "monthly" )
      _notify 'inf' "Setting postfix logrotate interval to monthly"
      LOGROTATE="${LOGROTATE}  rotate 4\n  monthly\n"
      ;;
    * ) _notify 'warn' 'LOGROTATE_INTERVAL not found in _setup_logrotate' ;;
  esac

  LOGROTATE="${LOGROTATE}}"
  echo -e "${LOGROTATE}" > /etc/logrotate.d/maillog
}

function _setup_mail_summary
{
  _notify 'inf' "Enable postfix summary with recipient ${PFLOGSUMM_RECIPIENT}"

  case "${PFLOGSUMM_TRIGGER}" in
    "daily_cron" )
      _notify 'inf' "Creating daily cron job for pflogsumm report"

      echo "#! /bin/bash" > /etc/cron.daily/postfix-summary
      echo "/usr/local/bin/report-pflogsumm-yesterday ${HOSTNAME} ${PFLOGSUMM_RECIPIENT} ${PFLOGSUMM_SENDER}" >> /etc/cron.daily/postfix-summary

      chmod +x /etc/cron.daily/postfix-summary
      ;;
    "logrotate" )
      _notify 'inf' "Add postrotate action for pflogsumm report"
      sed -i "s|}|  postrotate\n    /usr/local/bin/postfix-summary ${HOSTNAME} ${PFLOGSUMM_RECIPIENT} ${PFLOGSUMM_SENDER}\n  endscript\n}\n|" /etc/logrotate.d/maillog
      ;;
    "none" ) _notify 'inf' "Postfix log summary reports disabled. You can enable them with 'PFLOGSUMM_TRIGGER=daily_cron' or 'PFLOGSUMM_TRIGGER=logrotate'" ;;
    * ) _notify 'err' 'PFLOGSUMM_TRIGGER not found in _setup_mail_summery' ;;
  esac
}

function _setup_logwatch
{
  _notify 'inf' "Enable logwatch reports with recipient ${LOGWATCH_RECIPIENT}"

  echo "LogFile = /var/log/mail/freshclam.log" >> /etc/logwatch/conf/logfiles/clam-update.conf

  case "${LOGWATCH_INTERVAL}" in
    "daily" )
      _notify 'inf' "Creating daily cron job for logwatch reports"
      echo "#! /bin/bash" > /etc/cron.daily/logwatch
      echo "/usr/sbin/logwatch --range Yesterday --hostname ${HOSTNAME} --mailto ${LOGWATCH_RECIPIENT}" \
      >> /etc/cron.daily/logwatch
      chmod 744 /etc/cron.daily/logwatch
      ;;
    "weekly" )
      _notify 'inf' "Creating weekly cron job for logwatch reports"
      echo "#! /bin/bash" > /etc/cron.weekly/logwatch
      echo "/usr/sbin/logwatch --range 'between -7 days and -1 days' --hostname ${HOSTNAME} --mailto ${LOGWATCH_RECIPIENT}" \
      >> /etc/cron.weekly/logwatch
      chmod 744 /etc/cron.weekly/logwatch
      ;;
    "none" ) _notify 'inf' "Logwatch reports disabled. You can enable them with 'LOGWATCH_INTERVAL=daily' or 'LOGWATCH_INTERVAL=weekly'" ;;
    * ) _notify 'warn' 'LOGWATCH_INTERVAL not found in _setup_logwatch' ;;
  esac
}

function _setup_user_patches
{
  if [[ -f /tmp/docker-mailserver/user-patches.sh ]]
  then
    _notify 'inf' 'Executing user-patches.sh'
    chmod +x /tmp/docker-mailserver/user-patches.sh &>/dev/null || true

    if [[ -x /tmp/docker-mailserver/user-patches.sh ]]
    then
      /tmp/docker-mailserver/user-patches.sh
      _notify 'inf' "Executed 'config/user-patches.sh'"
    else
      _notify 'err' "Could not execute user-patches.sh. Not executable!"
    fi
  else
    _notify 'inf' "No user patches executed because optional '/tmp/docker-mailserver/user-patches.sh' is not provided."
  fi
}

function _setup_environment
{
  _notify 'task' 'Setting up /etc/environment'

  local BANNER="# Docker Environment"

  if ! grep -q "${BANNER}" /etc/environment
  then
      echo "${BANNER}" >> /etc/environment
      echo "VIRUSMAILS_DELETE_DELAY=${VIRUSMAILS_DELETE_DELAY}" >> /etc/environment
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


function fix
{
  _notify 'taskgrg' "Post-configuration checks..."
  for FUNC in "${FUNCS_FIX[@]}"
  do
    if ! ${FUNC}
    then
      _defunc
    fi
  done

  _notify 'taskgrg' "Remove leftover pid files from a stop/start"
  rm -rf /var/run/*.pid /var/run/*/*.pid
  touch /dev/shm/supervisor.sock
}

function _fix_var_mail_permissions
{
  _notify 'task' 'Checking /var/mail permissions'

  # dix permissions, but skip this if 3 levels deep the user id is already set
  if [[ $(find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .) -ne 0 ]]
  then
    _notify 'inf' "Fixing /var/mail permissions"
    chown -R 5000:5000 /var/mail
  else
    _notify 'inf' "Permissions in /var/mail look OK"
    return 0
  fi
}

function _fix_var_amavis_permissions
{
  if [[ ${ONE_DIR} -eq 0 ]]
  then
    amavis_state_dir=/var/lib/amavis
  else
    amavis_state_dir=/var/mail-state/lib-amavis
  fi

  # shellcheck disable=SC2016
  _notify 'task' 'Checking $amavis_state_dir permissions'

  amavis_permissions_status=$(find -H "${amavis_state_dir}" -maxdepth 3 -a \( \! -user amavis -o \! -group amavis \))

  if [[ -n ${amavis_permissions_status} ]]
  then
    _notify 'inf' "Fixing ${amavis_state_dir} permissions"
    chown -hR amavis:amavis "${amavis_state_dir}"
  else
    _notify 'inf' "Permissions in ${amavis_state_dir} look OK"
    return 0
  fi
}

function _fix_cleanup_clamav
{
    _notify 'task' 'Cleaning up disabled Clamav'
    rm -f /etc/logrotate.d/clamav-*
    rm -f /etc/cron.d/clamav-freshclam
}

function _fix_cleanup_spamassassin
{
    _notify 'task' 'Cleaning up disabled spamassassin'
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

function misc
{
  _notify 'tasklog' 'Startin misc'

  for FUNC in "${FUNCS_MISC[@]}"
  do
    if ! ${FUNC}
    then
      _defunc
    fi
  done
}

function _misc_save_states
{
  # consolidate all states into a single directory (`/var/mail-state`) to allow persistence using docker volumes
  statedir=/var/mail-state

  if [[ ${ONE_DIR} -eq 1 ]] && [[ -d ${statedir} ]]
  then
    _notify 'inf' "Consolidating all state onto ${statedir}"

    local FILES=(
      /var/spool/postfix
      /var/lib/postfix
      /var/lib/amavis
      /var/lib/clamav
      /var/lib/spamassassin
      /var/lib/fail2ban
      /var/lib/postgrey
      /var/lib/dovecot
    )

    for d in "${FILES[@]}"
    do
      dest="${statedir}/$(echo "${d}" | sed -e 's/.var.//; s/\//-/g')"

      if [[ -d ${dest} ]]
      then
        _notify 'inf' "  Destination ${dest} exists, linking ${d} to it"
        rm -rf "${d}"
        ln -s "${dest}" "${d}"
      elif [[ -d ${d} ]]
      then
        _notify 'inf' "  Moving contents of ${d} to ${dest}:" "$(ls "${d}")"
        mv "${d}" "${dest}"
        ln -s "${dest}" "${d}"
      else
        _notify 'inf' "  Linking ${d} to ${dest}"
        mkdir -p "${dest}"
        ln -s "${dest}" "${d}"
      fi
    done

    _notify 'inf' 'Fixing /var/mail-state/* permissions'
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

function start_daemons
{
  _notify 'tasklog' 'Starting mail server'

  for FUNC in "${DAEMONS_START[@]}"
  do
    if ! ${FUNC}
    then
      _defunc
    fi
  done
}

function _start_daemons_cron
{
  _notify 'task' 'Starting cron' 'n'
  supervisorctl start cron
}

function _start_daemons_rsyslog
{
  _notify 'task' 'Starting rsyslog ' 'n'
  supervisorctl start rsyslog
}

function _start_daemons_saslauthd
{
  _notify 'task' 'Starting saslauthd' 'n'
  supervisorctl start "saslauthd_${SASLAUTHD_MECHANISMS}"
}

function _start_daemons_fail2ban
{
  _notify 'task' 'Starting fail2ban ' 'n'
  touch /var/log/auth.log

  # delete fail2ban.sock that probably was left here after container restart
  if [[ -e /var/run/fail2ban/fail2ban.sock ]]
  then
    rm /var/run/fail2ban/fail2ban.sock
  fi

  supervisorctl start fail2ban
}

function _start_daemons_opendkim
{
  _notify 'task' 'Starting opendkim ' 'n'
  supervisorctl start opendkim
}

function _start_daemons_opendmarc
{
  _notify 'task' 'Starting opendmarc ' 'n'
  supervisorctl start opendmarc
}

function _start_daemons_postsrsd
{
  _notify 'task' 'Starting postsrsd ' 'n'
  supervisorctl start postsrsd
}

function _start_daemons_postfix
{
  _notify 'task' 'Starting postfix' 'n'
  supervisorctl start postfix
}

function _start_daemons_dovecot
{
  # Here we are starting sasl and imap, not pop3 because it's disabled by default
  _notify 'task' 'Starting dovecot services' 'n'

  if [[ ${ENABLE_POP3} -eq 1 ]]
  then
    _notify 'task' 'Starting pop3 services' 'n'
    mv /etc/dovecot/protocols.d/pop3d.protocol.disab /etc/dovecot/protocols.d/pop3d.protocol
  fi

  if [[ -f /tmp/docker-mailserver/dovecot.cf ]]
  then
    cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf
  fi

  supervisorctl start dovecot

  # TODO fix: on integration test
  # doveadm: Error: userdb lookup: connect(/var/run/dovecot/auth-userdb) failed: No such file or directory
  # doveadm: Fatal: user listing failed

  # if [[ ${ENABLE_LDAP} -ne 1 ]]
  # then
  #   echo "Listing users"
  #   /usr/sbin/dovecot user '*'
  # fi
}

function _start_daemons_fetchmail
{
  _notify 'task' 'Preparing fetchmail config'
  /usr/local/bin/setup-fetchmail
  if [[ ${FETCHMAIL_PARALLEL} -eq 1 ]]
  then
    mkdir /etc/fetchmailrc.d/
    /usr/local/bin/fetchmailrc_split

    COUNTER=0
    for RC in /etc/fetchmailrc.d/fetchmail-*.rc
    do
      COUNTER=$((COUNTER+1))
      cat <<EOF > "/etc/supervisor/conf.d/fetchmail-${COUNTER}.conf"
[program:fetchmail-${COUNTER}]
startsecs=0
autostart=false
autorestart=true
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
user=fetchmail
command=/usr/bin/fetchmail -f ${RC} -v --nodetach --daemon %(ENV_FETCHMAIL_POLL)s -i /var/lib/fetchmail/.fetchmail-UIDL-cache --pidfile /var/run/fetchmail/%(program_name)s.pid
EOF
      chmod 700 "${RC}"
      chown fetchmail:root "${RC}"
    done

    supervisorctl reread
    supervisorctl update

    COUNTER=0
    for _ in /etc/fetchmailrc.d/fetchmail-*.rc
    do
      COUNTER=$((COUNTER+1))
      _notify 'task' "Starting fetchmail instance ${COUNTER}" 'n'
      supervisorctl start "fetchmail-${COUNTER}"
    done

  else
    _notify 'task' 'Starting fetchmail' 'n'
    supervisorctl start fetchmail
  fi
}

function _start_daemons_clamav
{
  _notify 'task' 'Starting clamav' 'n'
  supervisorctl start clamav
}

function _start_daemons_postgrey
{
  _notify 'task' 'Starting postgrey' 'n'
  rm -f /var/run/postgrey/postgrey.pid
  supervisorctl start postgrey
}

function _start_daemons_amavis
{
  _notify 'task' 'Starting amavis' 'n'
  supervisorctl start amavis
}

##########################################################################
# << Start Daemons
##########################################################################


##########################################################################
# Start check for update postfix-accounts and postfix-virtual
##########################################################################

function _start_changedetector
{
  _notify 'task' 'Starting changedetector' 'n'
  supervisorctl start changedetector
}

# ! ––––––––––––––––––––––––––––––––––––––––––––––
# ! ––– CARE – BEGIN –––––––––––––––––––––––––––––
# ! ––––––––––––––––––––––––––––––––––––––––––––––

# shellcheck source=./helper-functions.sh
. /usr/local/bin/helper-functions.sh

if [[ ${DMS_DEBUG:-0} -eq 1 ]]
then
  _notify 'none'
  _notify 'tasklog' 'ENVIRONMENT'
  _notify 'none'

  printenv
fi

_notify 'none'
_notify 'tasklog' 'Welcome to docker-mailserver!'
_notify 'none'

register_functions

check
setup
fix
misc
start_daemons

_notify 'none'
_notify 'tasklog' "${HOSTNAME} is up and running"
_notify 'none'

touch /var/log/mail/mail.log
tail -fn 0 /var/log/mail/mail.log

# ! ––––––––––––––––––––––––––––––––––––––––––––––
# ! ––– CARE – END –––––––––––––––––––––––––––––––
# ! ––––––––––––––––––––––––––––––––––––––––––––––

exit 0
