#! /bin/bash

# ------------------------------------------------------------
# ? >> Sourcing helpers & stacks
#      1. Helpers
#      2. Checks
#      3. Setup
#      4. Fixes
#      5. Miscellaneous
#      6. Daemons
# ------------------------------------------------------------

# shellcheck source=./helpers/index.sh
source /usr/local/bin/helpers/index.sh

# shellcheck source=./startup/check-stack.sh
source /usr/local/bin/check-stack.sh

# shellcheck source=./startup/setup-stack.sh
source /usr/local/bin/setup-stack.sh

# shellcheck source=./startup/fixes-stack.sh
source /usr/local/bin/fixes-stack.sh

# shellcheck source=./startup/misc-stack.sh
source /usr/local/bin/misc-stack.sh

# shellcheck source=./startup/daemons-stack.sh
source /usr/local/bin/daemons-stack.sh

# ------------------------------------------------------------
# ? << Sourcing helpers & stacks
# --
# ? >> Setup Supervisor & DNS names
# ------------------------------------------------------------

# Setup supervisord as early as possible
declare -A VARS
VARS[SUPERVISOR_LOGLEVEL]="${SUPERVISOR_LOGLEVEL:=warn}"

_setup_supervisor
_obtain_hostname_and_domainname

# ------------------------------------------------------------
# ? << Setup Supervisor & DNS names
# --
# ? >> Setup of default and global values / variables
# ------------------------------------------------------------

# shellcheck disable=SC2034
declare -a FUNCS_SETUP FUNCS_FIX FUNCS_CHECK FUNCS_MISC DAEMONS_START

# These variables must be defined first; They are used as default values for other variables.
VARS[POSTMASTER_ADDRESS]="${POSTMASTER_ADDRESS:=postmaster@${DOMAINNAME}}"
VARS[REPORT_RECIPIENT]="${REPORT_RECIPIENT:=${POSTMASTER_ADDRESS}}"
VARS[REPORT_SENDER]="${REPORT_SENDER:=mailserver-report@${HOSTNAME}}"

VARS[AMAVIS_LOGLEVEL]="${AMAVIS_LOGLEVEL:=0}"
VARS[CLAMAV_MESSAGE_SIZE_LIMIT]="${CLAMAV_MESSAGE_SIZE_LIMIT:=25M}" # 25 MB
VARS[DEFAULT_RELAY_HOST]="${DEFAULT_RELAY_HOST:=}"
VARS[DOVECOT_INET_PROTOCOLS]="${DOVECOT_INET_PROTOCOLS:=all}"
VARS[DOVECOT_MAILBOX_FORMAT]="${DOVECOT_MAILBOX_FORMAT:=maildir}"
VARS[DOVECOT_TLS]="${DOVECOT_TLS:=no}"
VARS[ENABLE_AMAVIS]="${ENABLE_AMAVIS:=1}"
VARS[ENABLE_CLAMAV]="${ENABLE_CLAMAV:=0}"
VARS[ENABLE_DNSBL]="${ENABLE_DNSBL:=0}"
VARS[ENABLE_FAIL2BAN]="${ENABLE_FAIL2BAN:=0}"
VARS[ENABLE_FETCHMAIL]="${ENABLE_FETCHMAIL:=0}"
VARS[ENABLE_LDAP]="${ENABLE_LDAP:=0}"
VARS[ENABLE_MANAGESIEVE]="${ENABLE_MANAGESIEVE:=0}"
VARS[ENABLE_POP3]="${ENABLE_POP3:=0}"
VARS[ENABLE_POSTGREY]="${ENABLE_POSTGREY:=0}"
VARS[ENABLE_QUOTAS]="${ENABLE_QUOTAS:=1}"
VARS[ENABLE_SASLAUTHD]="${ENABLE_SASLAUTHD:=0}"
VARS[ENABLE_SPAMASSASSIN]="${ENABLE_SPAMASSASSIN:=0}"
VARS[ENABLE_SPAMASSASSIN_KAM]="${ENABLE_SPAMASSASSIN_KAM:=0}"
VARS[ENABLE_SRS]="${ENABLE_SRS:=0}"
VARS[ENABLE_UPDATE_CHECK]="${ENABLE_UPDATE_CHECK:=1}"
VARS[FAIL2BAN_BLOCKTYPE]="${FAIL2BAN_BLOCKTYPE:=drop}"
VARS[FETCHMAIL_PARALLEL]="${FETCHMAIL_PARALLEL:=0}"
VARS[FETCHMAIL_POLL]="${FETCHMAIL_POLL:=300}"
VARS[LDAP_START_TLS]="${LDAP_START_TLS:=no}"
VARS[LOG_LEVEL]="${LOG_LEVEL:=info}"
VARS[LOGROTATE_INTERVAL]="${LOGROTATE_INTERVAL:=weekly}"
VARS[LOGWATCH_INTERVAL]="${LOGWATCH_INTERVAL:=none}"
VARS[LOGWATCH_RECIPIENT]="${LOGWATCH_RECIPIENT:=${REPORT_RECIPIENT}}"
VARS[LOGWATCH_SENDER]="${LOGWATCH_SENDER:=${REPORT_SENDER}}"
VARS[MOVE_SPAM_TO_JUNK]="${MOVE_SPAM_TO_JUNK:=1}"
VARS[NETWORK_INTERFACE]="${NETWORK_INTERFACE:=eth0}"
VARS[ONE_DIR]="${ONE_DIR:=1}"
VARS[OVERRIDE_HOSTNAME]="${OVERRIDE_HOSTNAME:-}"
VARS[PERMIT_DOCKER]="${PERMIT_DOCKER:=none}"
VARS[PFLOGSUMM_RECIPIENT]="${PFLOGSUMM_RECIPIENT:=${REPORT_RECIPIENT}}"
VARS[PFLOGSUMM_SENDER]="${PFLOGSUMM_SENDER:=${REPORT_SENDER}}"
VARS[PFLOGSUMM_TRIGGER]="${PFLOGSUMM_TRIGGER:=none}"
VARS[POSTFIX_INET_PROTOCOLS]="${POSTFIX_INET_PROTOCOLS:=all}"
VARS[POSTFIX_MAILBOX_SIZE_LIMIT]="${POSTFIX_MAILBOX_SIZE_LIMIT:=0}"
VARS[POSTFIX_MESSAGE_SIZE_LIMIT]="${POSTFIX_MESSAGE_SIZE_LIMIT:=10240000}" # ~10 MB
VARS[POSTGREY_AUTO_WHITELIST_CLIENTS]="${POSTGREY_AUTO_WHITELIST_CLIENTS:=5}"
VARS[POSTGREY_DELAY]="${POSTGREY_DELAY:=300}"
VARS[POSTGREY_MAX_AGE]="${POSTGREY_MAX_AGE:=35}"
VARS[POSTGREY_TEXT]="${POSTGREY_TEXT:=Delayed by Postgrey}"
VARS[POSTSCREEN_ACTION]="${POSTSCREEN_ACTION:=enforce}"
VARS[RELAY_HOST]="${RELAY_HOST:=}"
VARS[SA_KILL]=${SA_KILL:="6.31"}
VARS[SA_SPAM_SUBJECT]=${SA_SPAM_SUBJECT:="***SPAM*** "}
VARS[SA_TAG]=${SA_TAG:="2.0"}
VARS[SA_TAG2]=${SA_TAG2:="6.31"}
VARS[SMTP_ONLY]="${SMTP_ONLY:=0}"
VARS[SPAMASSASSIN_SPAM_TO_INBOX]="${SPAMASSASSIN_SPAM_TO_INBOX:=1}"
VARS[SPOOF_PROTECTION]="${SPOOF_PROTECTION:=0}"
VARS[SRS_SENDER_CLASSES]="${SRS_SENDER_CLASSES:=envelope_sender}"
VARS[SSL_TYPE]="${SSL_TYPE:=}"
VARS[TLS_LEVEL]="${TLS_LEVEL:=modern}"
VARS[TZ]="${TZ:=}"
VARS[UPDATE_CHECK_INTERVAL]="${UPDATE_CHECK_INTERVAL:=1d}"
VARS[VIRUSMAILS_DELETE_DELAY]="${VIRUSMAILS_DELETE_DELAY:=7}"

# SASL specific variables
VARS[LDAP_BIND_DN]="${LDAP_BIND_DN:=}"
VARS[LDAP_BIND_PW]="${LDAP_BIND_PW:=}"
VARS[LDAP_SEARCH_BASE]="${LDAP_SEARCH_BASE:=}"
VARS[LDAP_SERVER_HOST]="${LDAP_SERVER_HOST:=}"

VARS[SASLAUTHD_LDAP_AUTH_METHOD]="${SASLAUTHD_LDAP_AUTH_METHOD:=bind}"
VARS[SASLAUTHD_LDAP_BIND_DN]="${SASLAUTHD_LDAP_BIND_DN:=${LDAP_BIND_DN}}"
VARS[SASLAUTHD_LDAP_FILTER]="${SASLAUTHD_LDAP_FILTER:=(&(uniqueIdentifier=%u)(mailEnabled=TRUE))}"
VARS[SASLAUTHD_LDAP_PASSWORD]="${SASLAUTHD_LDAP_PASSWORD:=${LDAP_BIND_PW}}"
VARS[SASLAUTHD_LDAP_SEARCH_BASE]="${SASLAUTHD_LDAP_SEARCH_BASE:=${LDAP_SEARCH_BASE}}"
VARS[SASLAUTHD_LDAP_SERVER]="${SASLAUTHD_LDAP_SERVER:=${LDAP_SERVER_HOST}}"
[[ ${SASLAUTHD_LDAP_SERVER} != *'://'* ]] && SASLAUTHD_LDAP_SERVER="ldap://${SASLAUTHD_LDAP_SERVER}"
VARS[SASLAUTHD_LDAP_START_TLS]="${SASLAUTHD_LDAP_START_TLS:=no}"
VARS[SASLAUTHD_LDAP_TLS_CHECK_PEER]="${SASLAUTHD_LDAP_TLS_CHECK_PEER:=no}"
VARS[SASLAUTHD_MECHANISMS]="${SASLAUTHD_MECHANISMS:=pam}"

if [[ -z ${SASLAUTHD_LDAP_TLS_CACERT_FILE} ]]
then
  SASLAUTHD_LDAP_TLS_CACERT_FILE=''
else
  SASLAUTHD_LDAP_TLS_CACERT_FILE="ldap_tls_cacert_file: ${SASLAUTHD_LDAP_TLS_CACERT_FILE}"
fi
VARS[SASLAUTHD_LDAP_TLS_CACERT_FILE]="${SASLAUTHD_LDAP_TLS_CACERT_FILE}"

if [[ -z ${SASLAUTHD_LDAP_TLS_CACERT_DIR} ]]
then
  SASLAUTHD_LDAP_TLS_CACERT_DIR=''
else
  SASLAUTHD_LDAP_TLS_CACERT_DIR="ldap_tls_cacert_dir: ${SASLAUTHD_LDAP_TLS_CACERT_DIR}"
fi
VARS[SASLAUTHD_LDAP_TLS_CACERT_DIR]="${SASLAUTHD_LDAP_TLS_CACERT_DIR}"

if [[ -z ${SASLAUTHD_LDAP_PASSWORD_ATTR} ]]
then
  SASLAUTHD_LDAP_PASSWORD_ATTR=''
else
  SASLAUTHD_LDAP_PASSWORD_ATTR="ldap_password_attr: ${SASLAUTHD_LDAP_PASSWORD_ATTR}"
fi
VARS[SASLAUTHD_LDAP_PASSWORD_ATTR]="${SASLAUTHD_LDAP_PASSWORD_ATTR}"

if [[ -z ${SASLAUTHD_LDAP_MECH} ]]
then
  SASLAUTHD_LDAP_MECH=''
else
  SASLAUTHD_LDAP_MECH="ldap_mech: ${SASLAUTHD_LDAP_MECH}"
fi
VARS[SASLAUTHD_LDAP_MECH]="${SASLAUTHD_LDAP_MECH}"

# ------------------------------------------------------------
# ? << Setup of default and global values / variables
# --
# ? >> Registering functions
# ------------------------------------------------------------

function _register_functions
{
  _log 'info' 'Initializing setup'
  _log 'debug' 'Registering functions'

  # ? >> Checks

  _register_check_function '_check_hostname'
  _register_check_function '_check_log_level'

  # ? >> Setup

  _register_setup_function '_setup_default_vars'
  _register_setup_function '_setup_file_permissions'

  [[ -n ${TZ} ]] && _register_setup_function '_setup_timezone'

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
  [[ ${POSTFIX_INET_PROTOCOLS} != 'all' ]] && _register_setup_function '_setup_postfix_inet_protocols'
  [[ ${DOVECOT_INET_PROTOCOLS} != 'all' ]] && _register_setup_function '_setup_dovecot_inet_protocols'
  [[ ${ENABLE_FAIL2BAN} -eq 1 ]] && _register_setup_function '_setup_fail2ban'
  [[ ${ENABLE_DNSBL} -eq 0 ]] && _register_setup_function '_setup_dnsbl_disable'
  [[ ${CLAMAV_MESSAGE_SIZE_LIMIT} != '25M' ]] && _register_setup_function '_setup_clamav_sizelimit'

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
  _register_setup_function '_setup_security_stack'
  _register_setup_function '_setup_postfix_aliases'
  _register_setup_function '_setup_postfix_vhost'
  _register_setup_function '_setup_postfix_dhparam'
  _register_setup_function '_setup_postfix_postscreen'
  _register_setup_function '_setup_postfix_sizelimits'

  # needs to come after _setup_postfix_aliases
  [[ ${SPOOF_PROTECTION} -eq 1 ]] && _register_setup_function '_setup_spoof_protection'

  if [[ ${ENABLE_FETCHMAIL} -eq 1 ]]
  then
    _register_setup_function '_setup_fetchmail'
    [[ ${FETCHMAIL_PARALLEL} -eq 1 ]] && _register_setup_function '_setup_fetchmail_parallel'
  fi

  if [[ ${ENABLE_SRS} -eq 1  ]]
  then
    _register_setup_function '_setup_SRS'
    _register_start_daemon '_start_daemon_postsrsd'
  fi

  _register_setup_function '_setup_postfix_access_control'
  _register_setup_function '_setup_postfix_relay_hosts'

  [[ ${ENABLE_POSTFIX_VIRTUAL_TRANSPORT:-0} -eq 1 ]] && _register_setup_function '_setup_postfix_virtual_transport'

  _register_setup_function '_setup_postfix_override_configuration'
  _register_setup_function '_setup_logrotate'
  _register_setup_function '_setup_mail_summary'
  _register_setup_function '_setup_logwatch'
  _register_setup_function '_setup_user_patches'

  # ? >> Fixes

  _register_fix_function '_fix_var_mail_permissions'
  [[ ${ENABLE_AMAVIS} -eq 1 ]] && _register_fix_function '_fix_var_amavis_permissions'

  [[ ${ENABLE_CLAMAV} -eq 0 ]] && _register_fix_function '_fix_cleanup_clamav'
  [[ ${ENABLE_SPAMASSASSIN} -eq 0 ]] &&	_register_fix_function '_fix_cleanup_spamassassin'

  # ? >> Miscellaneous

  _register_misc_function '_misc_save_states'

  # ? >> Daemons

  _register_start_daemon '_start_daemon_cron'
  _register_start_daemon '_start_daemon_rsyslog'

  [[ ${SMTP_ONLY} -ne 1 ]] && _register_start_daemon '_start_daemon_dovecot'
  [[ ${ENABLE_UPDATE_CHECK} -eq 1 ]] && _register_start_daemon '_start_daemon_update_check'

  # needs to be started before SASLauthd
  _register_start_daemon '_start_daemon_opendkim'
  _register_start_daemon '_start_daemon_opendmarc'

  # needs to be started before postfix
  [[ ${ENABLE_POSTGREY} -eq 1 ]] &&	_register_start_daemon '_start_daemon_postgrey'

  _register_start_daemon '_start_daemon_postfix'

  # needs to be started after postfix
  [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && _register_start_daemon '_start_daemon_saslauthd'
  [[ ${ENABLE_FAIL2BAN} -eq 1 ]] &&	_register_start_daemon '_start_daemon_fail2ban'
  [[ ${ENABLE_FETCHMAIL} -eq 1 ]] && _register_start_daemon '_start_daemon_fetchmail'
  [[ ${ENABLE_CLAMAV} -eq 1 ]] &&	_register_start_daemon '_start_daemon_clamav'
  [[ ${ENABLE_LDAP} -eq 0 ]] && _register_start_daemon '_start_daemon_changedetector'
  [[ ${ENABLE_AMAVIS} -eq 1 ]] && _register_start_daemon '_start_daemon_amavis'
}

function _register_start_daemon
{
  DAEMONS_START+=("${1}")
  _log 'trace' "${1}() registered"
}

function _register_setup_function
{
  FUNCS_SETUP+=("${1}")
  _log 'trace' "${1}() registered"
}

function _register_fix_function
{
  FUNCS_FIX+=("${1}")
  _log 'trace' "${1}() registered"
}

function _register_check_function
{
  FUNCS_CHECK+=("${1}")
  _log 'trace' "${1}() registered"
}

function _register_misc_function
{
  FUNCS_MISC+=("${1}")
  _log 'trace' "${1}() registered"
}

# ------------------------------------------------------------
# ? << Registering functions
# --
# ? >> Executing all stacks / actual start of DMS
# ------------------------------------------------------------

_log 'info' "Welcome to docker-mailserver $(</VERSION)"

_register_functions
_check
_setup
[[ ${LOG_LEVEL} =~ (debug|trace) ]] && print-environment
_apply_fixes
_start_misc
_start_daemons

# marker to check if container was restarted
date >/CONTAINER_START

_log 'info' "${HOSTNAME} is up and running"

touch /var/log/mail/mail.log
tail -Fn 0 /var/log/mail/mail.log

exit 0
