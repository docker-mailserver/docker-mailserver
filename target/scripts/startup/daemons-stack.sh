#! /bin/bash

function start_daemons
{
  _notify 'info' 'Starting daemons & mail server'
  for FUNC in "${DAEMONS_START[@]}"
  do
    ${FUNC}
  done
}

function _default_start_daemon
{
  _notify 'debug' "Starting ${1}"
  supervisorctl start "${1}" &>/dev/null || dms_panic__fail_init "${1}"
}

function _start_daemons_cron
{
  _default_start_daemon 'cron'
}

function _start_daemons_rsyslog
{
  _default_start_daemon 'rsyslog'
}

function _start_daemons_saslauthd
{
  _default_start_daemon "saslauthd_${SASLAUTHD_MECHANISMS}"
}

function _start_daemons_fail2ban
{
  touch /var/log/auth.log

  # delete fail2ban.sock that probably was left here after container restart
  if [[ -e /var/run/fail2ban/fail2ban.sock ]]
  then
    rm /var/run/fail2ban/fail2ban.sock
  fi

  _default_start_daemon 'fail2ban'
}

function _start_daemons_opendkim
{
  _default_start_daemon 'opendkim'
}

function _start_daemons_opendmarc
{
  _default_start_daemon 'opendmarc'
}

function _start_daemons_postsrsd
{
  _default_start_daemon 'postsrsd'
}

function _start_daemons_postfix
{
  _default_start_daemon 'postfix'
}

function _start_daemons_dovecot
{
  if [[ ${ENABLE_POP3} -eq 1 ]]
  then
    _notify 'debug' 'Starting pop3 services'
    mv /etc/dovecot/protocols.d/pop3d.protocol.disab /etc/dovecot/protocols.d/pop3d.protocol
  fi

  if [[ -f /tmp/docker-mailserver/dovecot.cf ]]
  then
    cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf
  fi

  _default_start_daemon 'dovecot'
}

function _start_daemons_fetchmail
{
  _notify 'debug' 'Preparing fetchmail config'
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
      _notify 'debug' "Starting fetchmail instance ${COUNTER}"
      supervisorctl start "fetchmail-${COUNTER}" || _panic__fail_init "fetchmail-${COUNTER}"
    done
  else
    _default_start_daemon 'fetchmail'
  fi
}

function _start_daemons_clamav
{
  _default_start_daemon 'clamav'
}

function _start_daemons_postgrey
{
  rm -f /var/run/postgrey/postgrey.pid
  _default_start_daemon 'postgrey'
}

function _start_daemons_amavis
{
  _default_start_daemon 'amavis'
}

function _start_changedetector
{
  _default_start_daemon 'changedetector'
}

function _start_daemons_update_check
{
  _default_start_daemon 'update-check'
}
