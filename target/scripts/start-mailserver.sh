#!/bin/bash

# When 'pipefail' is enabled, the exit status of the pipeline reflects the exit status of the last command that fails.
# Without 'pipefail', the exit status of a pipeline is determined by the exit status of the last command in the pipeline.
set -o pipefail

# Allows the usage of '**' in patterns, e.g. ls **/*
shopt -s globstar

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

  _register_check_function '_check_hostname'
  _register_check_function '_check_spam_prefix'

  # ? >> Setup

  _register_setup_function '_setup_vmail_id'
  _register_setup_function '_setup_timezone'

  if [[ ${SMTP_ONLY} -ne 1 ]]; then
    _register_setup_function '_setup_dovecot'
    _register_setup_function '_setup_dovecot_sieve'
    _register_setup_function '_setup_dovecot_quota'
    _register_setup_function '_setup_spam_subject'
    _register_setup_function '_setup_spam_to_junk'
    _register_setup_function '_setup_spam_mark_as_read'
  fi

  case "${ACCOUNT_PROVISIONER}" in
    ( 'FILE'  )
      _register_setup_function '_setup_dovecot_local_user'
      ;;

    ( 'LDAP' )
      _register_setup_function '_setup_ldap'
      ;;

    ( 'OIDC' )
      _dms_panic__fail_init 'OIDC user account provisioning - it is not yet implemented'
      ;;

    ( * )
      _dms_panic__invalid_value "'${ACCOUNT_PROVISIONER}' is not a valid value for ACCOUNT_PROVISIONER"
      ;;
  esac

  [[ ${ENABLE_OAUTH2} -eq 1 ]] && _register_setup_function '_setup_oauth2'
  [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && _register_setup_function '_setup_saslauthd'

  _register_setup_function '_setup_dovecot_inet_protocols'

  _register_setup_function '_setup_opendkim'
  _register_setup_function '_setup_opendmarc' # must come after `_setup_opendkim`
  _register_setup_function '_setup_policyd_spf'

  _register_setup_function '_setup_security_stack'
  _register_setup_function '_setup_rspamd'

  _register_setup_function '_setup_ssl'
  _register_setup_function '_setup_docker_permit'
  _register_setup_function '_setup_mailname'

  _register_setup_function '_setup_postfix_early'

  # Dependent upon _setup_postfix_early first calling _create_aliases
  # Due to conditional check for /etc/postfix/regexp
  _register_setup_function '_setup_spoof_protection'

  _register_setup_function '_setup_postfix_late'

  if [[ ${ENABLE_SRS} -eq 1  ]]; then
    _register_setup_function '_setup_SRS'
    _register_start_daemon '_start_daemon_postsrsd'
  fi

  _register_setup_function '_setup_fetchmail'
  _register_setup_function '_setup_fetchmail_parallel'
  _register_setup_function '_setup_getmail'

  _register_setup_function '_setup_logrotate'
  _register_setup_function '_setup_mail_summary'
  _register_setup_function '_setup_logwatch'

  _register_setup_function '_setup_save_states'
  _register_setup_function '_setup_adjust_state_permissions'

  if [[ ${ENABLE_MTA_STS} -eq 1 ]]; then
    _register_setup_function '_setup_mta_sts'
    _register_start_daemon '_start_daemon_mta_sts_daemon'
  fi

  # ! The following functions must be executed after all other setup functions
  _register_setup_function '_setup_directory_and_file_permissions'
  _register_setup_function '_setup_run_user_patches'

  # ? >> Daemons

  _register_start_daemon '_start_daemon_cron'
  _register_start_daemon '_start_daemon_rsyslog'

  [[ ${SMTP_ONLY} -ne 1 ]] && _register_start_daemon '_start_daemon_dovecot'

  if [[ ${ENABLE_UPDATE_CHECK} -eq 1 ]]; then
    if [[ ${DMS_RELEASE} != 'edge' ]]; then
      _register_start_daemon '_start_daemon_update_check'
    else
      _log 'warn' "ENABLE_UPDATE_CHECK=1 is configured, but image is not a stable release. Update-Check is disabled."
    fi
  fi

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
  [[ ${ENABLE_GETMAIL}          -eq 1 ]] && _register_start_daemon '_start_daemon_getmail'
}

# ------------------------------------------------------------
# ? << Registering functions
# --
# ? >> Executing all stacks / actual start of DMS
# ------------------------------------------------------------

_early_supervisor_setup
_early_variables_setup

_log 'info' "Welcome to docker-mailserver ${DMS_RELEASE}"

_register_functions
_check

# Ensure DMS only adjusts config files for a new container.
# Container restarts should skip as they retain the modified config.
if [[ -f /CONTAINER_START ]]; then
  _log 'info' 'Container was restarted. Skipping most setup routines.'
  # We cannot skip all setup routines because some need to run _after_
  # the initial setup (and hence, they cannot be moved to the check stack).
  _setup_directory_and_file_permissions

  # shellcheck source=./startup/setup.d/mail_state.sh
  source /usr/local/bin/setup.d/mail_state.sh
  _setup_adjust_state_permissions
else
  _setup
fi

# marker to check if container was restarted
date >/CONTAINER_START

# Container logs will receive updates from this log file:
MAIN_LOGFILE=/var/log/mail/mail.log
# NOTE: rsyslogd would usually create this later during `_start_daemons`, however it would already exist if the container was restarted.
touch "${MAIN_LOGFILE}"
# Ensure `tail` follows the correct position of the log file for this container start (new logs begin once `_start_daemons` is called)
TAIL_START=$(( $(wc -l < "${MAIN_LOGFILE}") + 1 ))

[[ ${LOG_LEVEL} =~ (debug|trace) ]] && print-environment
_start_daemons

# Container start-up scripts completed. `tail` will now pipe the log updates to stdout:
_log 'info' "${HOSTNAME} is up and running"
exec tail -Fn "+${TAIL_START}" "${MAIN_LOGFILE}"
