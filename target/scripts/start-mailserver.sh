#!/bin/bash

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
# ? >> Early setup & environment variables setup
# ------------------------------------------------------------

# shellcheck source=./helpers/variables.sh
source /usr/local/bin/helpers/variables.sh

_setup_supervisor
_obtain_hostname_and_domainname
_environment_variables_backwards_compatibility
_environment_variables_general_setup

# ------------------------------------------------------------
# ? << Early setup & environment variables setup
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

  _register_setup_function '_setup_file_permissions'
  _register_setup_function '_setup_timezone'

  if [[ ${SMTP_ONLY} -ne 1 ]]
  then
    _register_setup_function '_setup_dovecot'
    _register_setup_function '_setup_dovecot_dhparam'
    _register_setup_function '_setup_dovecot_quota'
  fi

  case "${ACCOUNT_PROVISIONER}" in
    ( 'FILE'  )
      _register_setup_function '_setup_dovecot_local_user'
      ;;

    ( 'LDAP' )
      _environment_variables_ldap
      _register_setup_function '_setup_ldap'
      ;;

    ( 'OIDC' )
      _register_setup_function '_setup_oidc'
      ;;

    ( * )
      _shutdown "'${ACCOUNT_PROVISIONER}' is not a valid value for ACCOUNT_PROVISIONER"
      ;;
  esac

  if [[ ${ENABLE_SASLAUTHD} -eq 1 ]]
  then
    _environment_variables_saslauthd
    _register_setup_function '_setup_saslauthd'
  fi

  [[ ${ENABLE_POSTGREY} -eq 1 ]] && _register_setup_function '_setup_postgrey'
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

  # ? >> Fixes

  _register_fix_function '_fix_var_mail_permissions'
  [[ ${ENABLE_AMAVIS} -eq 1 ]] && _register_fix_function '_fix_var_amavis_permissions'

  [[ ${ENABLE_CLAMAV} -eq 0 ]] && _register_fix_function '_fix_cleanup_clamav'
  [[ ${ENABLE_SPAMASSASSIN} -eq 0 ]] &&	_register_fix_function '_fix_cleanup_spamassassin'

  # ? >> Miscellaneous

  _register_misc_function '_misc_save_states'
  _register_setup_function '_environment_variables_export'

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
  [[ ${ACCOUNT_PROVISIONER} == 'FILE' ]] && _register_start_daemon '_start_daemon_changedetector'
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
_setup_user_patches
_start_daemons

# marker to check if container was restarted
date >/CONTAINER_START

_log 'info' "${HOSTNAME} is up and running"

touch /var/log/mail/mail.log
tail -Fn 0 /var/log/mail/mail.log

exit 0
