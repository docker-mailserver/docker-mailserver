#!/bin/bash

# shellcheck disable=SC2034
declare -A VARS

# shellcheck disable=SC2034
declare -a FUNCS_SETUP FUNCS_FIX FUNCS_CHECK FUNCS_MISC DAEMONS_START

# This function handles variables that are deprecated. This allows a
# smooth transition period, without the need of removing a variable
# completely with a single version.
function _environment_variables_backwards_compatibility
{
  if [[ ${ENABLE_LDAP:-0} -eq 1 ]]
  then
    _log 'warn' "'ENABLE_LDAP=1' is deprecated (and will be removed in v13.0.0) => use 'ACCOUNT_PROVISIONER=LDAP' instead"
    ACCOUNT_PROVISIONER='LDAP'
  fi

  # TODO this can be uncommented in a PR handling the HOSTNAME/DOMAINNAME issue
  # TODO see check_for_changes.sh and dns.sh
  # if [[ -n ${OVERRIDE_HOSTNAME:-} ]]
  # then
  #   _log 'warn' "'OVERRIDE_HOSTNAME' is deprecated (and will be removed in v13.0.0) => use 'DMS_FQDN' instead"
  #   [[ -z ${DMS_FQDN} ]] && DMS_FQDN=${OVERRIDE_HOSTNAME}
  # fi
}

# This function Writes the contents of the `VARS` map (associative array)
# to locations where they can be sourced from (e.g. `/etc/dms-settings`)
# or where they can be used by Bash directly (e.g. `/root/.bashrc`).
function _environment_variables_export
{
  _log 'debug' "Exporting environment variables now (creating '/etc/dms-settings')"

  : >/root/.bashrc     # make DMS variables available in login shells and their subprocesses
  : >/etc/dms-settings # this file can be sourced by other scripts

  local VAR
  for VAR in "${!VARS[@]}"
  do
    echo "export ${VAR}='${VARS[${VAR}]}'" >>/root/.bashrc
    echo "${VAR}='${VARS[${VAR}]}'"        >>/etc/dms-settings
  done

  sort -o /root/.bashrc     /root/.bashrc
  sort -o /etc/dms-settings /etc/dms-settings
}

# This function sets almost all environment variables. This involves setting
# a default if no value was provided and writing the variable and its value
# to the VARS map.
function _environment_variables_general_setup
{
  _log 'debug' 'Handling general environment variable setup'

  # these variables must be defined first
  # they are used as default values for other variables

  VARS[POSTMASTER_ADDRESS]="${POSTMASTER_ADDRESS:=postmaster@${DOMAINNAME}}"
  VARS[REPORT_RECIPIENT]="${REPORT_RECIPIENT:=${POSTMASTER_ADDRESS}}"
  VARS[REPORT_SENDER]="${REPORT_SENDER:=mailserver-report@${HOSTNAME}}"

  _log 'trace' 'Setting anti-spam & anti-virus environment variables'

  VARS[AMAVIS_LOGLEVEL]="${AMAVIS_LOGLEVEL:=0}"
  VARS[CLAMAV_MESSAGE_SIZE_LIMIT]="${CLAMAV_MESSAGE_SIZE_LIMIT:=25M}"
  VARS[FAIL2BAN_BLOCKTYPE]="${FAIL2BAN_BLOCKTYPE:=drop}"
  VARS[MOVE_SPAM_TO_JUNK]="${MOVE_SPAM_TO_JUNK:=1}"
  VARS[POSTGREY_AUTO_WHITELIST_CLIENTS]="${POSTGREY_AUTO_WHITELIST_CLIENTS:=5}"
  VARS[POSTGREY_DELAY]="${POSTGREY_DELAY:=300}"
  VARS[POSTGREY_MAX_AGE]="${POSTGREY_MAX_AGE:=35}"
  VARS[POSTGREY_TEXT]="${POSTGREY_TEXT:=Delayed by Postgrey}"
  VARS[POSTSCREEN_ACTION]="${POSTSCREEN_ACTION:=enforce}"
  VARS[SA_KILL]=${SA_KILL:="6.31"}
  VARS[SA_SPAM_SUBJECT]=${SA_SPAM_SUBJECT:="***SPAM*** "}
  VARS[SA_TAG]=${SA_TAG:="2.0"}
  VARS[SA_TAG2]=${SA_TAG2:="6.31"}
  VARS[SPAMASSASSIN_SPAM_TO_INBOX]="${SPAMASSASSIN_SPAM_TO_INBOX:=1}"
  VARS[SPOOF_PROTECTION]="${SPOOF_PROTECTION:=0}"
  VARS[VIRUSMAILS_DELETE_DELAY]="${VIRUSMAILS_DELETE_DELAY:=7}"

  _log 'trace' 'Setting service-enabling environment variables'

  VARS[ENABLE_AMAVIS]="${ENABLE_AMAVIS:=1}"
  VARS[ENABLE_CLAMAV]="${ENABLE_CLAMAV:=0}"
  VARS[ENABLE_DNSBL]="${ENABLE_DNSBL:=0}"
  VARS[ENABLE_FAIL2BAN]="${ENABLE_FAIL2BAN:=0}"
  VARS[ENABLE_FETCHMAIL]="${ENABLE_FETCHMAIL:=0}"
  VARS[ENABLE_MANAGESIEVE]="${ENABLE_MANAGESIEVE:=0}"
  VARS[ENABLE_POP3]="${ENABLE_POP3:=0}"
  VARS[ENABLE_POSTGREY]="${ENABLE_POSTGREY:=0}"
  VARS[ENABLE_QUOTAS]="${ENABLE_QUOTAS:=1}"
  VARS[ENABLE_SASLAUTHD]="${ENABLE_SASLAUTHD:=0}"
  VARS[ENABLE_SPAMASSASSIN]="${ENABLE_SPAMASSASSIN:=0}"
  VARS[ENABLE_SPAMASSASSIN_KAM]="${ENABLE_SPAMASSASSIN_KAM:=0}"
  VARS[ENABLE_SRS]="${ENABLE_SRS:=0}"
  VARS[ENABLE_UPDATE_CHECK]="${ENABLE_UPDATE_CHECK:=1}"

  _log 'trace' 'Setting IP, DNS and SSL environment variables'

  VARS[DEFAULT_RELAY_HOST]="${DEFAULT_RELAY_HOST:=}"
  # VARS[DMS_FQDN]="${DMS_FQDN:=}"
  # VARS[DMS_DOMAINNAME]="${DMS_DOMAINNAME:=}"
  # VARS[DMS_HOSTNAME]="${DMS_HOSTNAME:=}"
  VARS[NETWORK_INTERFACE]="${NETWORK_INTERFACE:=eth0}"
  VARS[OVERRIDE_HOSTNAME]="${OVERRIDE_HOSTNAME:-}"
  VARS[RELAY_HOST]="${RELAY_HOST:=}"
  VARS[SSL_TYPE]="${SSL_TYPE:=}"
  VARS[TLS_LEVEL]="${TLS_LEVEL:=modern}"

  _log 'trace' 'Setting Dovecot- and Postfix-specific environment variables'

  VARS[DOVECOT_INET_PROTOCOLS]="${DOVECOT_INET_PROTOCOLS:=all}"
  VARS[DOVECOT_MAILBOX_FORMAT]="${DOVECOT_MAILBOX_FORMAT:=maildir}"
  VARS[DOVECOT_TLS]="${DOVECOT_TLS:=no}"

  VARS[POSTFIX_INET_PROTOCOLS]="${POSTFIX_INET_PROTOCOLS:=all}"
  VARS[POSTFIX_MAILBOX_SIZE_LIMIT]="${POSTFIX_MAILBOX_SIZE_LIMIT:=0}"
  VARS[POSTFIX_MESSAGE_SIZE_LIMIT]="${POSTFIX_MESSAGE_SIZE_LIMIT:=10240000}" # ~10 MB

  _log 'trace' 'Setting miscellaneous environment variables'

  VARS[ACCOUNT_PROVISIONER]="${ACCOUNT_PROVISIONER:=FILE}"
  VARS[FETCHMAIL_PARALLEL]="${FETCHMAIL_PARALLEL:=0}"
  VARS[FETCHMAIL_POLL]="${FETCHMAIL_POLL:=300}"
  VARS[LOG_LEVEL]="${LOG_LEVEL:=info}"
  VARS[LOGROTATE_INTERVAL]="${LOGROTATE_INTERVAL:=weekly}"
  VARS[LOGWATCH_INTERVAL]="${LOGWATCH_INTERVAL:=none}"
  VARS[LOGWATCH_RECIPIENT]="${LOGWATCH_RECIPIENT:=${REPORT_RECIPIENT}}"
  VARS[LOGWATCH_SENDER]="${LOGWATCH_SENDER:=${REPORT_SENDER}}"
  VARS[ONE_DIR]="${ONE_DIR:=1}"
  VARS[PERMIT_DOCKER]="${PERMIT_DOCKER:=none}"
  VARS[PFLOGSUMM_RECIPIENT]="${PFLOGSUMM_RECIPIENT:=${REPORT_RECIPIENT}}"
  VARS[PFLOGSUMM_SENDER]="${PFLOGSUMM_SENDER:=${REPORT_SENDER}}"
  VARS[PFLOGSUMM_TRIGGER]="${PFLOGSUMM_TRIGGER:=none}"
  VARS[SMTP_ONLY]="${SMTP_ONLY:=0}"
  VARS[SRS_SENDER_CLASSES]="${SRS_SENDER_CLASSES:=envelope_sender}"
  VARS[SUPERVISOR_LOGLEVEL]="${SUPERVISOR_LOGLEVEL:=warn}"
  VARS[TZ]="${TZ:=}"
  VARS[UPDATE_CHECK_INTERVAL]="${UPDATE_CHECK_INTERVAL:=1d}"
}

# This function handles environment variables related to LDAP.
function _environment_variables_ldap
{
  _log 'debug' 'Setting LDAP-related environment variables now'

  VARS[LDAP_BIND_DN]="${LDAP_BIND_DN:=}"
  VARS[LDAP_BIND_PW]="${LDAP_BIND_PW:=}"
  VARS[LDAP_SEARCH_BASE]="${LDAP_SEARCH_BASE:=}"
  VARS[LDAP_SERVER_HOST]="${LDAP_SERVER_HOST:=}"
  VARS[LDAP_START_TLS]="${LDAP_START_TLS:=no}"
}

# This function handles environment variables related to SASLAUTHD
# and, if activated, variables related to SASLAUTHD and LDAP.
function _environment_variables_saslauthd
{
  _log 'debug' 'Setting SASLAUTHD-related environment variables now'

  VARS[SASLAUTHD_MECHANISMS]="${SASLAUTHD_MECHANISMS:=pam}"

  # SASL ENV for configuring an LDAP specific
  # `saslauthd.conf` via `setup-stack.sh:_setup_sasulauthd()`
  if [[ ${ACCOUNT_PROVISIONER} == 'LDAP' ]]
  then
    _log 'trace' 'Setting SASLSAUTH-LDAP variables nnow'

    VARS[SASLAUTHD_LDAP_AUTH_METHOD]="${SASLAUTHD_LDAP_AUTH_METHOD:=bind}"
    VARS[SASLAUTHD_LDAP_BIND_DN]="${SASLAUTHD_LDAP_BIND_DN:=${LDAP_BIND_DN}}"
    VARS[SASLAUTHD_LDAP_FILTER]="${SASLAUTHD_LDAP_FILTER:=(&(uniqueIdentifier=%u)(mailEnabled=TRUE))}"
    VARS[SASLAUTHD_LDAP_PASSWORD]="${SASLAUTHD_LDAP_PASSWORD:=${LDAP_BIND_PW}}"
    VARS[SASLAUTHD_LDAP_SEARCH_BASE]="${SASLAUTHD_LDAP_SEARCH_BASE:=${LDAP_SEARCH_BASE}}"
    VARS[SASLAUTHD_LDAP_SERVER]="${SASLAUTHD_LDAP_SERVER:=${LDAP_SERVER_HOST}}"
    [[ ${SASLAUTHD_LDAP_SERVER} != *'://'* ]] && SASLAUTHD_LDAP_SERVER="ldap://${SASLAUTHD_LDAP_SERVER}"
    VARS[SASLAUTHD_LDAP_START_TLS]="${SASLAUTHD_LDAP_START_TLS:=no}"
    VARS[SASLAUTHD_LDAP_TLS_CHECK_PEER]="${SASLAUTHD_LDAP_TLS_CHECK_PEER:=no}"

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
  fi
}
