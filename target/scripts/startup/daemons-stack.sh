#! /bin/bash

function start_daemons
{
  _notify 'tasklog' 'Starting daemons & mail server'
  for FUNC in "${DAEMONS_START[@]}"
  do
    ${FUNC}
  done
}

function _start_daemons_cron
{
  _notify 'task' 'Starting cron'
  supervisorctl start cron || dms_panic__fail_init 'cron'
}

function _start_daemons_rsyslog
{
  _notify 'task' 'Starting rsyslog'
  supervisorctl start rsyslog || dms_panic__fail_init 'rsyslog'
}

function _start_daemons_saslauthd
{
  _notify 'task' 'Starting saslauthd'
  supervisorctl start "saslauthd_${SASLAUTHD_MECHANISMS}" || dms_panic__fail_init 'saslauthd'
}

function _start_daemons_fail2ban
{
  _notify 'task' 'Starting Fail2ban'
  touch /var/log/auth.log

  # delete fail2ban.sock that probably was left here after container restart
  if [[ -e /var/run/fail2ban/fail2ban.sock ]]
  then
    rm /var/run/fail2ban/fail2ban.sock
  fi

  supervisorctl start fail2ban || dms_panic__fail_init 'Fail2ban'
}

function _start_daemons_opendkim
{
  _notify 'task' 'Starting opendkim'
  supervisorctl start opendkim || dms_panic__fail_init 'opendkim'
}

function _start_daemons_opendmarc
{
  _notify 'task' 'Starting opendmarc'
  supervisorctl start opendmarc || dms_panic__fail_init 'opendmarc'
}

function _start_daemons_postsrsd
{
  _notify 'task' 'Starting postsrsd'
  supervisorctl start postsrsd || dms_panic__fail_init 'postsrsd'
}

function _start_daemons_postfix
{
  _notify 'task' 'Starting postfix'
  supervisorctl start postfix || dms_panic__fail_init 'postfix'
}

function _start_daemons_dovecot
{
  _notify 'task' 'Starting dovecot services'

  if [[ ${ENABLE_POP3} -eq 1 ]]
  then
    _notify 'task' 'Starting pop3 services'
    mv /etc/dovecot/protocols.d/pop3d.protocol.disab \
      /etc/dovecot/protocols.d/pop3d.protocol
  fi

  if [[ -f /tmp/docker-mailserver/dovecot.cf ]]
  then
    cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf
  fi

  supervisorctl start dovecot || dms_panic__fail_init 'dovecot'
}

function _start_daemons_fetchmail
{
  _notify 'task' 'Preparing fetchmail config'
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
      _notify 'task' "Starting fetchmail instance ${COUNTER}"
      supervisorctl start "fetchmail-${COUNTER}" || _panic__fail_init "fetchmail-${COUNTER}"
    done
  else
    _notify 'task' 'Starting fetchmail'
    supervisorctl start fetchmail || dms_panic__fail_init 'fetchmail'
  fi
}

function _start_daemons_clamav
{
  _notify 'task' 'Starting clamav'
  supervisorctl start clamav || dms_panic__fail_init 'ClamAV'
}

function _start_daemons_postgrey
{
  _notify 'task' 'Starting postgrey'
  rm -f /var/run/postgrey/postgrey.pid
  supervisorctl start postgrey || dms_panic__fail_init 'postgrey'
}

function _start_daemons_amavis
{
  _notify 'task' 'Starting amavis'
  supervisorctl start amavis || dms_panic__fail_init 'amavis'
}

function _start_changedetector
{
  _notify 'task' 'Starting changedetector'
  supervisorctl start changedetector || dms_panic__fail_init 'changedetector'
}

function _start_daemons_update_check
{
  _notify 'task' 'Starting update-check'
  supervisorctl start update-check || dms_panic__fail_init 'update-check'
}
