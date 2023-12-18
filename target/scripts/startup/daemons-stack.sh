#!/bin/bash

declare -a DAEMONS_START

function _register_start_daemon() {
  DAEMONS_START+=("${1}")
  _log 'trace' "${1}() registered"
}

function _start_daemons() {
  _log 'info' 'Starting daemons'

  for FUNCTION in "${DAEMONS_START[@]}"; do
    ${FUNCTION}
  done
}

function _default_start_daemon() {
  _log 'debug' "Starting ${1:?}"

  local RESULT
  RESULT=$(supervisorctl start "${1}" 2>&1)

  # shellcheck disable=SC2181
  if [[ ${?} -ne 0 ]]; then
    _log 'error' "${RESULT}"
    _dms_panic__fail_init "${1}"
  fi
}

function _start_daemon_amavis         { _default_start_daemon 'amavis'         ; }
function _start_daemon_changedetector { _default_start_daemon 'changedetector' ; }
function _start_daemon_clamav         { _default_start_daemon 'clamav'         ; }
function _start_daemon_cron           { _default_start_daemon 'cron'           ; }
function _start_daemon_dovecot        { _default_start_daemon 'dovecot'        ; }
function _start_daemon_fail2ban       { _default_start_daemon 'fail2ban'       ; }
function _start_daemon_opendkim       { _default_start_daemon 'opendkim'       ; }
function _start_daemon_opendmarc      { _default_start_daemon 'opendmarc'      ; }
function _start_daemon_postgrey       { _default_start_daemon 'postgrey'       ; }
function _start_daemon_postsrsd       { _default_start_daemon 'postsrsd'       ; }
function _start_daemon_rspamd         { _default_start_daemon 'rspamd'         ; }
function _start_daemon_rspamd_redis   { _default_start_daemon 'rspamd-redis'   ; }
function _start_daemon_rsyslog        { _default_start_daemon 'rsyslog'        ; }
function _start_daemon_update_check   { _default_start_daemon 'update-check'   ; }

function _start_daemon_saslauthd() {
  _default_start_daemon "saslauthd_${SASLAUTHD_MECHANISMS}"
}

function _start_daemon_postfix() {
  _adjust_mtime_for_postfix_maincf
  _default_start_daemon 'postfix'
}

function _start_daemon_fetchmail() {
  if [[ ${FETCHMAIL_PARALLEL} -eq 1 ]]; then
    local COUNTER=0
    for _ in /etc/fetchmailrc.d/fetchmail-*.rc; do
      COUNTER=$(( COUNTER + 1 ))
      _default_start_daemon "fetchmail-${COUNTER}"
    done
  else
    _default_start_daemon 'fetchmail'
  fi
}
