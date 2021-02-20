#! /bin/bash

function fix
{
  _notify 'inf' "Post-configuration checks"
  for FUNC in "${FUNCS_FIX[@]}"
  do
    if ! ${FUNC}
    then
      _defunc
    fi
  done

  _notify 'inf' "Removing leftover PID files from a stop/start"
  rm -rf /var/run/*.pid /var/run/*/*.pid
  touch /dev/shm/supervisor.sock
}

function _fix_var_mail_permissions
{
  _notify 'task' 'Checking /var/mail permissions'

  # fix permissions, but skip this if 3 levels deep the user id is already set
  if [[ $(find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .) -ne 0 ]]
  then
    _notify 'inf' "Fixing /var/mail permissions"
    chown -R 5000:5000 /var/mail
  else
    _notify 'inf' "Permissions in /var/mail look OK"
    return 0
  fi
}

function _fix_var_amavis_permissions
{
  local AMAVIS_STATE_DIR="/var/mail-state/lib-amavis"
  [[ ${ONE_DIR} -eq 0 ]] && AMAVIS_STATE_DIR="/var/lib/amavis"
  [[ ! -e ${AMAVIS_STATE_DIR} ]] && return 0

  _notify 'inf' 'Checking and fixing Amavis permissions'
  chown -hR amavis:amavis "${AMAVIS_STATE_DIR}"

  return 0
}

function _fix_cleanup_clamav
{
  _notify 'task' 'Cleaning up disabled Clamav'
  rm -f /etc/logrotate.d/clamav-*
  rm -f /etc/cron.d/clamav-freshclam
}

function _fix_cleanup_spamassassin
{
  _notify 'task' 'Cleaning up disabled spamassassin'
  rm -f /etc/cron.daily/spamassassin
}
