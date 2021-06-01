#! /bin/bash

# shellcheck source=./helper-functions.sh
. /usr/local/bin/helper-functions.sh

unset FUNCS_SETUP FUNCS_FIX FUNCS_CHECK FUNCS_MISC
unset DAEMONS_START HOSTNAME DOMAINNAME CHKSUM_FILE

#shellcheck disable=SC2034
declare -A VARS
declare -a FUNCS_SETUP FUNCS_FIX FUNCS_CHECK FUNCS_MISC DAEMONS_START

# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# ? <<
# ––
# ? >> Setup of default and global values / variables
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

VARS[AMAVIS_LOGLEVEL]="${AMAVIS_LOGLEVEL:=0}"
VARS[DEFAULT_RELAY_HOST]="${DEFAULT_RELAY_HOST:=}"
VARS[DMS_DEBUG]="${DMS_DEBUG:=0}"
VARS[DOVECOT_MAILBOX_FORMAT]="${DOVECOT_MAILBOX_FORMAT:=maildir}"
VARS[DOVECOT_TLS]="${DOVECOT_TLS:=no}"
VARS[ENABLE_AMAVIS]="${ENABLE_AMAVIS:=1}"
VARS[ENABLE_CLAMAV]="${ENABLE_CLAMAV:=0}"
VARS[ENABLE_FAIL2BAN]="${ENABLE_FAIL2BAN:=0}"
VARS[ENABLE_FETCHMAIL]="${ENABLE_FETCHMAIL:=0}"
VARS[ENABLE_LDAP]="${ENABLE_LDAP:=0}"
VARS[ENABLE_MANAGESIEVE]="${ENABLE_MANAGESIEVE:=0}"
VARS[ENABLE_POP3]="${ENABLE_POP3:=0}"
VARS[ENABLE_POSTGREY]="${ENABLE_POSTGREY:=0}"
VARS[ENABLE_QUOTAS]="${ENABLE_QUOTAS:=1}"
VARS[ENABLE_SASLAUTHD]="${ENABLE_SASLAUTHD:=0}"
VARS[ENABLE_SPAMASSASSIN]="${ENABLE_SPAMASSASSIN:=0}"
VARS[ENABLE_SRS]="${ENABLE_SRS:=0}"
VARS[ENABLE_UPDATE_CHECK]="${ENABLE_UPDATE_CHECK:=1}"
VARS[FAIL2BAN_BLOCKTYPE]="${FAIL2BAN_BLOCKTYPE:=drop}"
VARS[FETCHMAIL_POLL]="${FETCHMAIL_POLL:=300}"
VARS[FETCHMAIL_PARALLEL]="${FETCHMAIL_PARALLEL:=0}"
VARS[LDAP_START_TLS]="${LDAP_START_TLS:=no}"
VARS[LOGROTATE_INTERVAL]="${LOGROTATE_INTERVAL:=${REPORT_INTERVAL:-daily}}"
VARS[LOGWATCH_INTERVAL]="${LOGWATCH_INTERVAL:=none}"
VARS[MOVE_SPAM_TO_JUNK]="${MOVE_SPAM_TO_JUNK:=1}"
VARS[NETWORK_INTERFACE]="${NETWORK_INTERFACE:=eth0}"
VARS[ONE_DIR]="${ONE_DIR:=0}"
VARS[OVERRIDE_HOSTNAME]="${OVERRIDE_HOSTNAME}"
VARS[POSTGREY_AUTO_WHITELIST_CLIENTS]="${POSTGREY_AUTO_WHITELIST_CLIENTS:=5}"
VARS[POSTGREY_DELAY]="${POSTGREY_DELAY:=300}"
VARS[POSTGREY_MAX_AGE]="${POSTGREY_MAX_AGE:=35}"
VARS[POSTGREY_TEXT]="${POSTGREY_TEXT:=Delayed by Postgrey}"
VARS[POSTFIX_INET_PROTOCOLS]="${POSTFIX_INET_PROTOCOLS:=all}"
VARS[POSTFIX_MAILBOX_SIZE_LIMIT]="${POSTFIX_MAILBOX_SIZE_LIMIT:=0}"
VARS[POSTFIX_MESSAGE_SIZE_LIMIT]="${POSTFIX_MESSAGE_SIZE_LIMIT:=10240000}" # ~10MB
VARS[POSTSCREEN_ACTION]="${POSTSCREEN_ACTION:=enforce}"
VARS[RELAY_HOST]="${RELAY_HOST:=}"
VARS[REPORT_RECIPIENT]="${REPORT_RECIPIENT:="0"}"
VARS[SMTP_ONLY]="${SMTP_ONLY:=0}"
VARS[SPAMASSASSIN_SPAM_TO_INBOX_SET]="${SPAMASSASSIN_SPAM_TO_INBOX:-not set}"
VARS[SPAMASSASSIN_SPAM_TO_INBOX]="${SPAMASSASSIN_SPAM_TO_INBOX:=0}"
VARS[SPOOF_PROTECTION]="${SPOOF_PROTECTION:=0}"
VARS[SRS_SENDER_CLASSES]="${SRS_SENDER_CLASSES:=envelope_sender}"
VARS[SSL_TYPE]="${SSL_TYPE:=}"
VARS[SUPERVISOR_LOGLEVEL]="${SUPERVISOR_LOGLEVEL:=warn}"
VARS[TLS_LEVEL]="${TLS_LEVEL:=modern}"
VARS[UPDATE_CHECK_INTERVAL]="${UPDATE_CHECK_INTERVAL:=1d}"
VARS[VIRUSMAILS_DELETE_DELAY]="${VIRUSMAILS_DELETE_DELAY:=7}"

export HOSTNAME DOMAINNAME CHKSUM_FILE

HOSTNAME="$(hostname -f)"
DOMAINNAME="$(hostname -d)"
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum

# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# ? << Setup of default and global values / variables
# ––
# ? >> Registering functions
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

function register_functions
{
  _notify 'tasklog' 'Initializing setup'
  _notify 'task' 'Registering functions'

  # ? >> Checks

  _register_check_function '_check_hostname'

  # ? >> Setup

  _register_setup_function '_setup_supervisor'
  _register_setup_function '_setup_default_vars'
  _register_setup_function '_setup_file_permissions'

  if [[ ${SMTP_ONLY} -ne 1 ]]
  then
    _register_setup_function '_setup_dovecot'
    _register_setup_function '_setup_dovecot_dhparam'
    _register_setup_function '_setup_dovecot_quota'
    _register_setup_function '_setup_dovecot_local_user'
  fi

  [[ ${ENABLE_LDAP} -eq 1 ]] && _register_setup_function '_setup_ldap'
  [[ ${ENABLE_POSTGREY} -eq 1 ]] && _register_setup_function '_setup_postgrey'
  [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && _register_setup_function '_setup_saslauthd'
  [[ ${POSTFIX_INET_PROTOCOLS} != 'all' ]] && _register_setup_function '_setup_inet_protocols'
  [[ ${ENABLE_FAIL2BAN} -eq 1 ]] && _register_setup_function '_setup_fail2ban'

  _register_setup_function '_setup_dkim'
  _register_setup_function '_setup_ssl'
  _register_setup_function '_setup_docker_permit'
  _register_setup_function '_setup_mailname'
  _register_setup_function '_setup_amavis'
  _register_setup_function '_setup_dmarc_hostname'
  _register_setup_function '_setup_postfix_hostname'
  _register_setup_function '_setup_dovecot_hostname'
  _register_setup_function '_setup_postfix_smtputf8'
  _register_setup_function '_setup_postfix_sasl'
  _register_setup_function '_setup_postfix_sasl_password'
  _register_setup_function '_setup_security_stack'
  _register_setup_function '_setup_postfix_aliases'
  _register_setup_function '_setup_postfix_vhost'
  _register_setup_function '_setup_postfix_dhparam'
  _register_setup_function '_setup_postfix_postscreen'
  _register_setup_function '_setup_postfix_sizelimits'

  # needs to come after _setup_postfix_aliases
  [[ ${SPOOF_PROTECTION} -eq 1 ]] && _register_setup_function '_setup_spoof_protection'

  if [[ ${ENABLE_SRS} -eq 1  ]]
  then
    _register_setup_function '_setup_SRS'
    _register_start_daemon '_start_daemons_postsrsd'
  fi

  _register_setup_function '_setup_postfix_access_control'

  [[ -n ${DEFAULT_RELAY_HOST} ]] && _register_setup_function '_setup_postfix_default_relay_host'
  [[ -n ${RELAY_HOST} ]] && _register_setup_function '_setup_postfix_relay_hosts'
  [[ ${ENABLE_POSTFIX_VIRTUAL_TRANSPORT:-0} -eq 1 ]] && _register_setup_function '_setup_postfix_virtual_transport'

  _register_setup_function '_setup_postfix_override_configuration'
  _register_setup_function '_setup_environment'
  _register_setup_function '_setup_logrotate'
  _register_setup_function '_setup_mail_summary'
  _register_setup_function '_setup_logwatch'
  _register_setup_function '_setup_user_patches'

  # needs to come last as configuration files are modified in-place
  _register_setup_function '_setup_chksum_file'

  # ? >> Fixes

  _register_fix_function '_fix_var_mail_permissions'
  [[ ${ENABLE_AMAVIS} -eq 1 ]] && _register_fix_function '_fix_var_amavis_permissions'

  [[ ${ENABLE_CLAMAV} -eq 0 ]] && _register_fix_function '_fix_cleanup_clamav'
  [[ ${ENABLE_SPAMASSASSIN} -eq 0 ]] &&	_register_fix_function '_fix_cleanup_spamassassin'

  # ? >> Miscellaneous

  _register_misc_function '_misc_save_states'

  # ? >> Daemons

  _register_start_daemon '_start_daemons_cron'
  _register_start_daemon '_start_daemons_rsyslog'

  [[ ${SMTP_ONLY} -ne 1 ]] && _register_start_daemon '_start_daemons_dovecot'
  [[ ${ENABLE_UPDATE_CHECK} -eq 1 ]] && _register_start_daemon '_start_daemons_update_check'

  # needs to be started before SASLauthd
  _register_start_daemon '_start_daemons_opendkim'
  _register_start_daemon '_start_daemons_opendmarc'

  # needs to be started before postfix
  [[ ${ENABLE_POSTGREY} -eq 1 ]] &&	_register_start_daemon '_start_daemons_postgrey'

  _register_start_daemon '_start_daemons_postfix'

  # needs to be started after postfix
  [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && _register_start_daemon '_start_daemons_saslauthd'
  [[ ${ENABLE_FAIL2BAN} -eq 1 ]] &&	_register_start_daemon '_start_daemons_fail2ban'
  [[ ${ENABLE_FETCHMAIL} -eq 1 ]] && _register_start_daemon '_start_daemons_fetchmail'
  [[ ${ENABLE_CLAMAV} -eq 1 ]] &&	_register_start_daemon '_start_daemons_clamav'
  [[ ${ENABLE_LDAP} -eq 0 ]] && _register_start_daemon '_start_changedetector'
  [[ ${ENABLE_AMAVIS} -eq 1 ]] && _register_start_daemon '_start_daemons_amavis'
}

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

function _defunc
{
  _notify 'fatal' 'Please fix your configuration. Exiting...'
  exit 1
}

# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# ? << Registering functions
# ––
# ? >> Sourcing all stacks
#      1. Checks
#      2. Setup
#      3. Fixes
#      4. Miscellaneous
#      5. Daemons
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

# shellcheck source=./startup/check-stack.sh
. /usr/local/bin/check-stack.sh

# shellcheck source=./startup/setup-stack.sh
. /usr/local/bin/setup-stack.sh

# shellcheck source=./startup/fixes-stack.sh
. /usr/local/bin/fixes-stack.sh

# shellcheck source=./startup/misc-stack.sh
. /usr/local/bin/misc-stack.sh

# shellcheck source=./startup/daemons-stack.sh
. /usr/local/bin/daemons-stack.sh

# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# ? << Sourcing all stacks
# ––
# ? >> Executing all stacks
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

_notify 'tasklog' "Welcome to docker-mailserver $(</VERSION)"
_notify 'inf' 'ENVIRONMENT'
[[ ${DMS_DEBUG} -eq 1 ]] && printenv

register_functions
check
setup
fix
start_misc
start_daemons

_notify 'tasklog' "${HOSTNAME} is up and running"

touch /var/log/mail/mail.log
tail -Fn 0 /var/log/mail/mail.log

exit 0
