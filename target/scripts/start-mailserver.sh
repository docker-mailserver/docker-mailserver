#!/bin/bash

# ------------------------------------------------------------
# ? >> Sourcing helpers & startup stacks
# ------------------------------------------------------------

# shellcheck source=./helpers/index.sh
source /usr/local/bin/helpers/index.sh

# shellcheck source=./startup/check-stack.sh
source /usr/local/bin/check-stack.sh

# shellcheck source=./startup/setup-stack.sh
source /usr/local/bin/setup-stack.sh

# shellcheck source=./startup/daemons-stack.sh
source /usr/local/bin/daemons-stack.sh

# ------------------------------------------------------------
# ? << Sourcing helpers & startup stacks
# --
# ? >> Registering functions
# ------------------------------------------------------------

function _register_functions
{
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

  [[ ${ENABLE_POSTGREY} -eq 1 ]]              && _register_setup_function '_setup_postgrey'
  [[ ${POSTFIX_INET_PROTOCOLS} != 'all' ]]    && _register_setup_function '_setup_postfix_inet_protocols'
  [[ ${DOVECOT_INET_PROTOCOLS} != 'all' ]]    && _register_setup_function '_setup_dovecot_inet_protocols'
  [[ ${ENABLE_FAIL2BAN} -eq 1 ]]              && _register_setup_function '_setup_fail2ban'
  [[ ${ENABLE_DNSBL} -eq 0 ]]                 && _register_setup_function '_setup_dnsbl_disable'
  [[ ${CLAMAV_MESSAGE_SIZE_LIMIT} != '25M' ]] && _register_setup_function '_setup_clamav_sizelimit'
  [[ ${ENABLE_RSPAMD} -eq 1 ]]                && _register_setup_function '_setup_rspamd'

  _register_setup_function '_setup_dkim_dmarc'
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

  [[ -n ${POSTFIX_DAGENT} ]] && _register_setup_function '_setup_postfix_virtual_transport'

  _register_setup_function '_setup_postfix_override_configuration'
  _register_setup_function '_setup_logrotate'
  _register_setup_function '_setup_mail_summary'
  _register_setup_function '_setup_logwatch'

  _register_setup_function '_setup_apply_fixes'
  _register_setup_function '_setup_save_states'
  _register_setup_function '_environment_variables_export'

  # ? >> Daemons

  _register_start_daemon '_start_daemon_cron'
  _register_start_daemon '_start_daemon_rsyslog'

  if [[ ${ENABLE_RSPAMD} -eq 1 ]]
  then
    _register_start_daemon '_start_daemon_redis'
    _register_start_daemon '_start_daemon_rspamd'
  fi

  [[ ${SMTP_ONLY} -ne 1 ]]               && _register_start_daemon '_start_daemon_dovecot'
  [[ ${ENABLE_UPDATE_CHECK} -eq 1 ]]     && _register_start_daemon '_start_daemon_update_check'

  # needs to be started before SASLauthd
  [[ ${ENABLE_OPENDKIM} -eq 1 ]]         && _register_start_daemon '_start_daemon_opendkim'
  [[ ${ENABLE_OPENDMARC} -eq 1 ]]        && _register_start_daemon '_start_daemon_opendmarc'

  # needs to be started before postfix
  [[ ${ENABLE_POSTGREY} -eq 1 ]]         &&	_register_start_daemon '_start_daemon_postgrey'

  _register_start_daemon '_start_daemon_postfix'

  # needs to be started after postfix
  [[ ${ENABLE_SASLAUTHD} -eq 1 ]]        && _register_start_daemon '_start_daemon_saslauthd'
  [[ ${ENABLE_FAIL2BAN} -eq 1 ]]         &&	_register_start_daemon '_start_daemon_fail2ban'
  [[ ${ENABLE_FETCHMAIL} -eq 1 ]]        && _register_start_daemon '_start_daemon_fetchmail'
  [[ ${ENABLE_CLAMAV} -eq 1 ]]           &&	_register_start_daemon '_start_daemon_clamav'
  [[ ${ENABLE_AMAVIS} -eq 1 ]]           && _register_start_daemon '_start_daemon_amavis'
  [[ ${ACCOUNT_PROVISIONER} == 'FILE' ]] && _register_start_daemon '_start_daemon_changedetector'
}

# ------------------------------------------------------------
# ? << Registering functions
# --
# ? >> Actual start of DMS
# ------------------------------------------------------------

_run_early_setup
_log 'info' "Welcome to docker-mailserver $(</VERSION)"

_register_functions
_check
_setup
_start_daemons

# marker to check if container was restarted
date >/CONTAINER_START

_log 'info' "${HOSTNAME} is up and running"

touch /var/log/mail/mail.log
tail -Fn 0 /var/log/mail/mail.log

exit 0
