#! /bin/bash

# shellcheck source=./helper-functions.sh
. /usr/local/bin/helper-functions.sh

unset FUNCS_SETUP FUNCS_FIX FUNCS_CHECK FUNCS_MISC DAEMONS_START
export HOSTNAME DOMAINNAME CHKSUM_FILE
declare -a FUNCS_SETUP FUNCS_FIX FUNCS_CHECK FUNCS_MISC DAEMONS_START

# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# ? <<
# ––
# ? >> Setup of default and global values / variables
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

DEFAULT_RELAY_HOST="${DEFAULT_RELAY_HOST:=}"
DMS_DEBUG="${DMS_DEBUG:=0}"
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
POSTFIX_MAILBOX_SIZE_LIMIT="${POSTFIX_MAILBOX_SIZE_LIMIT:=0}"
POSTFIX_MESSAGE_SIZE_LIMIT="${POSTFIX_MESSAGE_SIZE_LIMIT:=10240000}" # ~10MB
POSTSCREEN_ACTION="${POSTSCREEN_ACTION:=enforce}"
RELAY_HOST="${RELAY_HOST:=}"
REPORT_RECIPIENT="${REPORT_RECIPIENT:="0"}"
SMTP_ONLY="${SMTP_ONLY:=0}"
SPAMASSASSIN_SPAM_TO_INBOX_IS_SET="$(\
  if [[ -n ${SPAMASSASSIN_SPAM_TO_INBOX+'set'} ]]; \
  then echo true ; else echo false ; fi )"
SPAMASSASSIN_SPAM_TO_INBOX="${SPAMASSASSIN_SPAM_TO_INBOX:=0}"
SPOOF_PROTECTION="${SPOOF_PROTECTION:=0}"
SRS_SENDER_CLASSES="${SRS_SENDER_CLASSES:=envelope_sender}"
SSL_TYPE="${SSL_TYPE:=}"
SUPERVISOR_LOGLEVEL="${SUPERVISOR_LOGLEVEL:=warn}"
TLS_LEVEL="${TLS_LEVEL:=modern}"
VIRUSMAILS_DELETE_DELAY="${VIRUSMAILS_DELETE_DELAY:=7}"

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

  _register_check_function "_check_hostname"

  # ? >> Setup

  _register_setup_function "_setup_supervisor"
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
  [[ ${ENABLE_POSTGREY} -eq 1 ]] && _register_setup_function "_setup_postgrey"
  [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && _register_setup_function "_setup_saslauthd"
  [[ ${POSTFIX_INET_PROTOCOLS} != "all" ]] && _register_setup_function "_setup_inet_protocols"

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

  # needs to come after _setup_postfix_aliases
  [[ ${SPOOF_PROTECTION} -eq 1 ]] && _register_setup_function "_setup_spoof_protection"

  if [[ ${ENABLE_SRS} -eq 1  ]]
  then
    _register_setup_function "_setup_SRS"
    _register_start_daemon "_start_daemons_postsrsd"
  fi

  _register_setup_function "_setup_postfix_access_control"

  [[ -n ${DEFAULT_RELAY_HOST} ]] && _register_setup_function "_setup_postfix_default_relay_host"
  [[ -n ${RELAY_HOST} ]] && _register_setup_function "_setup_postfix_relay_hosts"
  [[ ${ENABLE_POSTFIX_VIRTUAL_TRANSPORT:-0} -eq 1 ]] && _register_setup_function "_setup_postfix_virtual_transport"

  _register_setup_function "_setup_postfix_override_configuration"
  _register_setup_function "_setup_environment"
  _register_setup_function "_setup_logrotate"
  _register_setup_function "_setup_mail_summary"
  _register_setup_function "_setup_logwatch"
  _register_setup_function "_setup_user_patches"

  # needs to come last as configuration files are modified in-place
  _register_setup_function "_setup_chksum_file"

  # ? >> Fixes

  _register_fix_function "_fix_var_mail_permissions"
  _register_fix_function "_fix_var_amavis_permissions"

  [[ ${ENABLE_CLAMAV} -eq 0 ]] && _register_fix_function "_fix_cleanup_clamav"
  [[ ${ENABLE_SPAMASSASSIN} -eq 0 ]] &&	_register_fix_function "_fix_cleanup_spamassassin"

  # ? >> Miscellaneous

  _register_misc_function "_misc_save_states"

  # ? >> Daemons

  _register_start_daemon "_start_daemons_cron"
  _register_start_daemon "_start_daemons_rsyslog"

  [[ ${SMTP_ONLY} -ne 1 ]] && _register_start_daemon "_start_daemons_dovecot"

  # needs to be started before SASLauthd
  _register_start_daemon "_start_daemons_opendkim"
  _register_start_daemon "_start_daemons_opendmarc"

  # needs to be started before postfix
  [[ ${ENABLE_POSTGREY} -eq 1 ]] &&	_register_start_daemon "_start_daemons_postgrey"

  _register_start_daemon "_start_daemons_postfix"

  # needs to be started after postfix
  [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && _register_start_daemon "_start_daemons_saslauthd"
  [[ ${ENABLE_FAIL2BAN} -eq 1 ]] &&	_register_start_daemon "_start_daemons_fail2ban"
  [[ ${ENABLE_FETCHMAIL} -eq 1 ]] && _register_start_daemon "_start_daemons_fetchmail"
  [[ ${ENABLE_CLAMAV} -eq 1 ]] &&	_register_start_daemon "_start_daemons_clamav"
  [[ ${ENABLE_LDAP} -eq 0 ]] && _register_start_daemon "_start_changedetector"

  _register_start_daemon "_start_daemons_amavis"
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
# ? >> Running all stacks
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
# ? << Running all stacks
# ––
# ? >> Final function calls and script execution
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

_notify 'inf' 'Welcome to docker-mailserver'
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
tail -fn 0 /var/log/mail/mail.log

exit 0
