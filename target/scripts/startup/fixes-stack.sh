#! /bin/bash

function fix
{
  _notify 'tasklog' 'Post-configuration checks'
  for FUNC in "${FUNCS_FIX[@]}"
  do
    ${FUNC}
  done

  _notify 'inf' 'Removing leftover PID files from a stop/start'
  find /var/run/ -not -name 'supervisord.pid' -name '*.pid' -delete
  touch /dev/shm/supervisor.sock
}

function _fix_var_mail_permissions
{
  _notify 'task' 'Checking /var/mail permissions'

  # fix permissions, but skip this if 3 levels deep the user id is already set
  if find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | read -r
  then
    _notify 'inf' 'Fixing /var/mail permissions'
    chown -R 5000:5000 /var/mail || _shutdown 'Failed to fix /var/mail permissions'
  else
    _notify 'inf' 'Permissions in /var/mail look OK'
  fi
}

function _fix_var_amavis_permissions
{
  local AMAVIS_STATE_DIR='/var/mail-state/lib-amavis'
  [[ ${ONE_DIR} -eq 0 ]] && AMAVIS_STATE_DIR="/var/lib/amavis"
  [[ ! -e ${AMAVIS_STATE_DIR} ]] && return 0

  _notify 'inf' 'Fixing Amavis permissions'
  chown -hR amavis:amavis "${AMAVIS_STATE_DIR}" || _shutdown 'Failed to fix Amavis permissions'
}

function _fix_cleanup_clamav
{
  _notify 'task' 'Cleaning up disabled ClamAV'
  rm /etc/logrotate.d/clamav-* /etc/cron.d/clamav-freshclam || {
    # show error only on first container start
    [[ ! -f /CONTAINER_START ]] && _notify 'err' 'Failed to remove ClamAV configuration'
  }
}

function _fix_cleanup_spamassassin
{
  _notify 'task' 'Cleaning up disabled SpamAssassin'
  rm /etc/cron.daily/spamassassin || {
    # show error only on first container start
    [[ ! -f /CONTAINER_START ]] && _notify 'err' 'Failed to remove SpamAssassin configuration'
  }
}
