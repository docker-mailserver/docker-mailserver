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

  # Adapts the permissions of the /var/mail folder.
  mail_owner_user=$(stat -c '%u' /var/mail)
  mail_owner_group=$(stat -c '%g' /var/mail)

  if [ $ENABLE_LDAP = 1 ] && ([ ${mail_owner_user} -ne 5000 ] || [ ${mail_owner_group} -ne 5000 ]); then
    _notify 'inf' 'Fixing /var/mail permissions to fit LDAP-enabled needs'
    chown 5000:5000 /var/mail || _shutdown 'Failed to fix /var/mail permissions to fit LDAP needs'
  elif find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | read -r; then
    _notify 'inf' 'Fixing /var/mail permissions to fit LDAP-disabled needs'
    chown -R 5000:5000 /var/mail || _shutdown 'Failed to fix /var/mail permissions to fit LDAP needs'
  else
    _notify 'inf' 'Permissions of /var/mail look OK'
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
  rm /etc/logrotate.d/clamav-* /etc/cron.d/clamav-freshclam || _notify 'err' 'Failed to remove ClamAV configuration'
}

function _fix_cleanup_spamassassin
{
  _notify 'task' 'Cleaning up disabled SpamAssassin'
  rm /etc/cron.daily/spamassassin || _notify 'err' 'Failed to remove SpamAssassin configuration'
}
