#!/bin/bash

set -o pipefail
shopt -s globstar inherit_errexit

# ------------------------------------------------------------
# ? >> Sourcing helpers & stacks
# ------------------------------------------------------------

# shellcheck source=./helpers/index.sh
source /usr/local/bin/helpers/index.sh

# shellcheck source=./startup/variables-stack.sh
source /usr/local/bin/variables-stack.sh

# shellcheck source=./startup/check-stack.sh
source /usr/local/bin/check-stack.sh

# shellcheck source=./startup/setup-stack.sh
source /usr/local/bin/setup-stack.sh

# shellcheck source=./startup/daemons-stack.sh
source /usr/local/bin/daemons-stack.sh

# ------------------------------------------------------------
# ? << Sourcing helpers & stacks
# --
# ? >> Registering functions
# ------------------------------------------------------------

function _register_functions() {
  _log 'debug' 'Registering functions'

  # ? >> Checks

  _register_check_function '_check_improper_restart'
  _register_check_function '_check_hostname'
  _register_check_function '_check_log_level'

  # ? >> Setup

  _register_setup_function '_setup_vmail_id'
  _register_setup_function '_setup_logs_general'
  _register_setup_function '_setup_timezone'

  if [[ ${SMTP_ONLY} -ne 1 ]]; then
    _register_setup_function '_setup_dovecot'
    _register_setup_function '_setup_dovecot_sieve'
    _register_setup_function '_setup_dovecot_dhparam'
    _register_setup_function '_setup_dovecot_quota'
    _register_setup_function '_setup_spam_to_junk'
    _register_setup_function '_setup_spam_mark_as_read'
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
      _dms_panic__fail_init 'OIDC user account provisioning - it is not yet implemented'
      ;;

    ( * )
      _dms_panic__invalid_value "'${ACCOUNT_PROVISIONER}' is not a valid value for ACCOUNT_PROVISIONER"
      ;;
  esac

  if [[ ${ENABLE_SASLAUTHD} -eq 1 ]]; then
    _environment_variables_saslauthd
    _register_setup_function '_setup_saslauthd'
  fi

  _register_setup_function '_setup_dovecot_inet_protocols'

  _register_setup_function '_setup_opendkim'
  _register_setup_function '_setup_opendmarc' # must come after `_setup_opendkim`
  _register_setup_function '_setup_policyd_spf'

  _register_setup_function '_setup_security_stack'
  _register_setup_function '_setup_rspamd'

  _register_setup_function '_setup_ssl'
  _register_setup_function '_setup_docker_permit'
  _register_setup_function '_setup_mailname'
  _register_setup_function '_setup_dovecot_hostname'

  _register_setup_function '_setup_postfix_early'
  _register_setup_function '_setup_fetchmail'
  _register_setup_function '_setup_fetchmail_parallel'

  # needs to come after _setup_postfix_early
  _register_setup_function '_setup_spoof_protection'

  _register_setup_function '_setup_getmail'

  if [[ ${ENABLE_SRS} -eq 1  ]]; then
    _register_setup_function '_setup_SRS'
    _register_start_daemon '_start_daemon_postsrsd'
  fi

  _register_setup_function '_setup_postfix_late'
  _register_setup_function '_setup_logrotate'
  _register_setup_function '_setup_mail_summary'
  _register_setup_function '_setup_logwatch'

  _register_setup_function '_setup_save_states'
  _register_setup_function '_setup_apply_fixes_after_configuration'
  _register_setup_function '_environment_variables_export'

  # ? >> Daemons

  _register_start_daemon '_start_daemon_cron'
  _register_start_daemon '_start_daemon_rsyslog'

  [[ ${SMTP_ONLY}               -ne 1 ]] && _register_start_daemon '_start_daemon_dovecot'

  [[ ${ENABLE_UPDATE_CHECK}     -eq 1 ]] && _register_start_daemon '_start_daemon_update_check'

  # The order here matters: Since Rspamd is using Redis, Redis should be started before Rspamd.
  [[ ${ENABLE_RSPAMD_REDIS}     -eq 1 ]] && _register_start_daemon '_start_daemon_rspamd_redis'
  [[ ${ENABLE_RSPAMD}           -eq 1 ]] && _register_start_daemon '_start_daemon_rspamd'

  # needs to be started before SASLauthd
  [[ ${ENABLE_OPENDKIM}         -eq 1 ]] && _register_start_daemon '_start_daemon_opendkim'
  [[ ${ENABLE_OPENDMARC}        -eq 1 ]] && _register_start_daemon '_start_daemon_opendmarc'

  # needs to be started before postfix
  [[ ${ENABLE_POSTGREY}         -eq 1 ]] &&	_register_start_daemon '_start_daemon_postgrey'

  _register_start_daemon '_start_daemon_postfix'

  # needs to be started after postfix
  [[ ${ENABLE_SASLAUTHD}        -eq 1 ]] && _register_start_daemon '_start_daemon_saslauthd'
  [[ ${ENABLE_FAIL2BAN}         -eq 1 ]] &&	_register_start_daemon '_start_daemon_fail2ban'
  [[ ${ENABLE_FETCHMAIL}        -eq 1 ]] && _register_start_daemon '_start_daemon_fetchmail'
  [[ ${ENABLE_CLAMAV}           -eq 1 ]] &&	_register_start_daemon '_start_daemon_clamav'
  [[ ${ENABLE_AMAVIS}           -eq 1 ]] && _register_start_daemon '_start_daemon_amavis'
  [[ ${ACCOUNT_PROVISIONER} == 'FILE' ]] && _register_start_daemon '_start_daemon_changedetector'
}

# ------------------------------------------------------------
# ? << Registering functions
# --
# ? >> Executing all stacks / actual start of DMS
# ------------------------------------------------------------

_early_supervisor_setup
_early_variables_setup

_log 'info' "Welcome to docker-mailserver $(</VERSION)"

_register_functions
_check
_setup
[[ ${LOG_LEVEL} =~ (debug|trace) ]] && print-environment
_run_user_patches
_start_daemons

# marker to check if container was restarted
date >/CONTAINER_START

_log 'info' "${HOSTNAME} is up and running"

touch /var/log/mail/mail.log
tail -Fn 0 /var/log/mail/mail.log

exit 0
