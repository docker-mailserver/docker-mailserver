#!/bin/bash

function _setup_logs_general() {
  _log 'debug' 'Setting up general log files'

  # File/folder permissions are fine when using docker volumes, but may be wrong
  # when file system folders are mounted into the container.
  # Set the expected values and create missing folders/files just in case.
  mkdir -p /var/log/{mail,supervisor}
  chown syslog:root /var/log/mail
}

function _setup_logrotate() {
  _log 'debug' 'Setting up logrotate'

  if [[ ${LOGROTATE_INTERVAL} =~ ^(daily|weekly|monthly)$ ]]; then
    _log 'trace' "Logrotate interval set to ${LOGROTATE_INTERVAL}"
  else
    _dms_panic__invalid_value 'LOGROTATE_INTERVAL' 'Setup -> Logrotate'
  fi

  cat >/etc/logrotate.d/maillog << EOF
/var/log/mail/mail.log
{
  compress
  copytruncate
  delaycompress
  rotate 4
  ${LOGROTATE_INTERVAL}
}
EOF
}

function _setup_mail_summary() {
  local ENABLED_MESSAGE
  ENABLED_MESSAGE="Enabling Postfix log summary reports with recipient '${PFLOGSUMM_RECIPIENT}'"

  case "${PFLOGSUMM_TRIGGER}" in
    ( 'daily_cron' )
      _log 'debug' "${ENABLED_MESSAGE}"
      _log 'trace' 'Creating daily cron job for pflogsumm report'

      cat >/etc/cron.daily/postfix-summary << EOF
#!/bin/bash

/usr/local/bin/report-pflogsumm-yesterday ${HOSTNAME} ${PFLOGSUMM_RECIPIENT} ${PFLOGSUMM_SENDER}
EOF

      chmod +x /etc/cron.daily/postfix-summary
      ;;

    ( 'logrotate' )
      _log 'debug' "${ENABLED_MESSAGE}"
      _log 'trace' 'Add postrotate action for pflogsumm report'
      sed -i \
        "s|}|  postrotate\n    /usr/local/bin/postfix-summary ${HOSTNAME} ${PFLOGSUMM_RECIPIENT} ${PFLOGSUMM_SENDER}\n  endscript\n}\n|" \
        /etc/logrotate.d/maillog
      ;;

    ( 'none' )
      _log 'debug' 'Postfix log summary reports disabled'
      ;;

    ( * )
      _log 'warn' "Invalid value for PFLOGSUMM_TRIGGER: '${PFLOGSUMM_TRIGGER}'"
      ;;

  esac
}

function _setup_logwatch() {
  echo 'LogFile = /var/log/mail/freshclam.log' >>/etc/logwatch/conf/logfiles/clam-update.conf
  echo "MailFrom = ${LOGWATCH_SENDER}" >>/etc/logwatch/conf/logwatch.conf
  echo "Mailer = \"sendmail -t -f ${LOGWATCH_SENDER}\"" >>/etc/logwatch/conf/logwatch.conf

  case "${LOGWATCH_INTERVAL}" in
    ( 'daily' | 'weekly' )
      _log 'debug' "Enabling logwatch reports with recipient '${LOGWATCH_RECIPIENT}'"
      _log 'trace' "Creating ${LOGWATCH_INTERVAL} cron job for logwatch reports"

      local LOGWATCH_FILE INTERVAL

      LOGWATCH_FILE="/etc/cron.${LOGWATCH_INTERVAL}/logwatch"
      INTERVAL='--range Yesterday'

      if [[ ${LOGWATCH_INTERVAL} == 'weekly' ]]; then
        INTERVAL="--range 'between -7 days and -1 days'"
      fi

      cat >"${LOGWATCH_FILE}" << EOF
#!/bin/bash

/usr/sbin/logwatch ${INTERVAL} --hostname ${HOSTNAME} --mailto ${LOGWATCH_RECIPIENT}
EOF
      chmod 744 "${LOGWATCH_FILE}"
      ;;

    ( 'none' )
      _log 'debug' 'Logwatch reports disabled.'
      ;;

    ( * )
      _log 'warn' "Invalid value for LOGWATCH_INTERVAL: '${LOGWATCH_INTERVAL}'"
      ;;

  esac
}
