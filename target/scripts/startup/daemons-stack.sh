#! /bin/bash

function _start_daemons
{
  _log 'info' 'Starting daemons'

  for FUNCTION in "${DAEMONS_START[@]}"
  do
    ${FUNCTION}
  done
}

function _default_start_daemon
{
  _log 'debug' "Starting ${1:?}"

  local RESULT
  RESULT="$(supervisorctl start "${1}" 2>&1)"

  # shellcheck disable=SC2181
  if [[ ${?} -ne 0 ]]
  then
    echo "${RESULT}" >&2
    dms_panic__fail_init "${1}"
  fi
}

function _start_daemon_changedetector { _default_start_daemon 'changedetector' ; }
function _start_daemon_amavis         { _default_start_daemon 'amavis'         ; }
function _start_daemon_clamav         { _default_start_daemon 'clamav'         ; }
function _start_daemon_cron           { _default_start_daemon 'cron'           ; }
function _start_daemon_opendkim       { _default_start_daemon 'opendkim'       ; }
function _start_daemon_opendmarc      { _default_start_daemon 'opendmarc'      ; }
function _start_daemon_postsrsd       { _default_start_daemon 'postsrsd'       ; }
function _start_daemon_postfix        { _default_start_daemon 'postfix'        ; }
function _start_daemon_rsyslog        { _default_start_daemon 'rsyslog'        ; }
function _start_daemon_update_check   { _default_start_daemon 'update-check'   ; }

function _start_daemon_saslauthd
{
  _default_start_daemon "saslauthd_${SASLAUTHD_MECHANISMS}"
}

function _start_daemon_postgrey
{
  rm -f /var/run/postgrey/postgrey.pid
  _default_start_daemon 'postgrey'
}

function _start_daemon_fail2ban
{
  touch /var/log/auth.log

  # delete fail2ban.sock that probably was left here after container restart
  [[ -e /var/run/fail2ban/fail2ban.sock ]] && rm /var/run/fail2ban/fail2ban.sock

  _default_start_daemon 'fail2ban'
}

function _start_daemon_dovecot
{
  if [[ ${ENABLE_POP3} -eq 1 ]]
  then
    _log 'debug' 'Starting POP3 services'
    mv /etc/dovecot/protocols.d/pop3d.protocol.disab /etc/dovecot/protocols.d/pop3d.protocol
  fi

  [[ -f /tmp/docker-mailserver/dovecot.cf ]] && cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf

  _default_start_daemon 'dovecot'
}

function _start_daemons_fetchmail
{
  _log 'debug' 'Preparing fetchmail config'
  /usr/local/bin/setup-fetchmail

  if [[ ${FETCHMAIL_PARALLEL} -eq 1 ]]
  then
    mkdir /etc/fetchmailrc.d/
    /usr/local/bin/fetchmailrc_split

    local COUNTER=0
    for RC in /etc/fetchmailrc.d/fetchmail-*.rc
    do
      COUNTER=$(( COUNTER + 1 ))
      cat >"/etc/supervisor/conf.d/fetchmail-${COUNTER}.conf" << EOF
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
      COUNTER=$(( COUNTER + 1 ))
      _log 'debug' "Starting fetchmail instance ${COUNTER}"
      supervisorctl start "fetchmail-${COUNTER}" || _panic__fail_init "fetchmail-${COUNTER}"
    done
  else
    _log 'debug' 'Starting fetchmail'
    supervisorctl start fetchmail || dms_panic__fail_init 'fetchmail'
  fi
}
