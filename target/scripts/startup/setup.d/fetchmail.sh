#!/bin/bash

function _setup_fetchmail() {
  if [[ ${ENABLE_FETCHMAIL} -eq 1 ]]; then
    _log 'trace' 'Enabling and configuring Fetchmail'

    local CONFIGURATION FETCHMAILRC

    CONFIGURATION='/tmp/docker-mailserver/fetchmail.cf'
    FETCHMAILRC='/etc/fetchmailrc'

    if [[ -f ${CONFIGURATION} ]]; then
      cat /etc/fetchmailrc_general "${CONFIGURATION}" >"${FETCHMAILRC}"
    else
      cat /etc/fetchmailrc_general >"${FETCHMAILRC}"
    fi

    chmod 700 "${FETCHMAILRC}"
    chown fetchmail:root "${FETCHMAILRC}"
  else
    _log 'debug' 'Fetchmail is disabled'
  fi
}

function _setup_fetchmail_parallel() {
  if [[ ${FETCHMAIL_PARALLEL} -eq 1 ]]; then
    _log 'trace' 'Enabling and configuring Fetchmail parallel'
    mkdir /etc/fetchmailrc.d/

    # Split the content of /etc/fetchmailrc into
    # smaller fetchmailrc files per server [poll] entries. Each
    # separate fetchmailrc file is stored in /etc/fetchmailrc.d
    #
    # The sole purpose for this is to work around what is known
    # as the Fetchmail IMAP idle issue.
    function _fetchmailrc_split() {
      local FETCHMAILRC='/etc/fetchmailrc'
      local FETCHMAILRCD='/etc/fetchmailrc.d'
      local DEFAULT_FILE="${FETCHMAILRCD}/defaults"

      if [[ ! -r ${FETCHMAILRC} ]]; then
        _log 'warn' "File '${FETCHMAILRC}' not found"
        return 1
      fi

      if [[ ! -d ${FETCHMAILRCD} ]]; then
        if ! mkdir "${FETCHMAILRCD}"; then
          _log 'warn' "Unable to create folder '${FETCHMAILRCD}'"
          return 1
        fi
      fi

      local COUNTER=0 SERVER=0
      while read -r LINE; do
        if [[ ${LINE} =~ poll ]]; then
          # If we read "poll" then we reached a new server definition
          # We need to create a new file with fetchmail defaults from
          # /etc/fetcmailrc
          COUNTER=$(( COUNTER + 1 ))
          SERVER=1
          cat "${DEFAULT_FILE}" >"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
          echo "${LINE}" >>"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
        elif [[ ${SERVER} -eq 0 ]]; then
          # We have not yet found "poll". Let's assume we are still reading
          # the default settings from /etc/fetchmailrc file
          echo "${LINE}" >>"${DEFAULT_FILE}"
        else
          # Just the server settings that need to be added to the specific rc.d file
          echo "${LINE}" >>"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
        fi
      done < <(_get_valid_lines_from_file "${FETCHMAILRC}")

      rm "${DEFAULT_FILE}"
    }

    _fetchmailrc_split

    local COUNTER=0
    for RC in /etc/fetchmailrc.d/fetchmail-*.rc; do
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
  else
    _log 'debug' 'Fetchmail parallel is disabled'
  fi
}
